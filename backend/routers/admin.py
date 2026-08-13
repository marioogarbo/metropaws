from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy.orm import Session, joinedload, selectinload
from sqlalchemy import func
from typing import Optional
from datetime import datetime, timezone
import logging
import os
from database import get_db
import models, schemas, auth as auth_utils
import reimbursement_utils as rutils
import invoice_utils

# When "true", the admin who approved a claim may NOT also mark it paid
# (segregation of duties). Off by default so single-admin setups still work.
_ENFORCE_DUAL_CONTROL = os.getenv("REIMBURSEMENT_ENFORCE_DUAL_CONTROL", "false").lower() == "true"

from paw_points_utils import award_points

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["admin"])


def _award_service_points(db, member_id: str, service_name: str, log_id: str) -> None:
    member = db.query(models.Member).filter(models.Member.id == member_id).first()
    if not member:
        return
    activity = (
        "service_deployed_grooming"
        if "groom" in service_name.lower()
        else "service_deployed_vet"
    )
    award_points(
        db,
        member_id=member_id,
        activity_type=activity,
        plan_type=member.plan_type,
        reference_id=log_id,
    )


@router.get("/scan/{qr_token}", response_model=schemas.MemberSummary)
def scan_qr(
    qr_token: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    # Try pet-level QR first (QR encodes pet.id — the primary key, no extra column needed)
    pet = (
        db.query(models.Pet)
        .options(joinedload(models.Pet.pet_services).joinedload(models.PetService.service_type))
        .filter(models.Pet.id == qr_token)
        .first()
    )
    if pet:
        member = (
            db.query(models.Member)
            .options(joinedload(models.Member.services).joinedload(models.MemberService.service_type))
            .filter(models.Member.id == pet.member_id)
            .first()
        )
        if not member:
            raise HTTPException(status_code=404, detail="Member not found for this pet")
        # Return MemberSummary with only the scanned pet
        return schemas.MemberSummary(
            id=member.id,
            email=member.email,
            first_name=member.first_name,
            last_name=member.last_name,
            plan_type=member.plan_type,
            qr_token=member.qr_token,
            is_founding=member.is_founding,
            joined_at=member.joined_at,
            pets=[schemas.PetOut.model_validate(pet)],
            services=[schemas.MemberServiceOut.model_validate(s) for s in member.services],
        )

    # Fall back to member-level QR (legacy / admin lookup)
    member = (
        db.query(models.Member)
        .options(
            joinedload(models.Member.pets).joinedload(models.Pet.pet_services).joinedload(models.PetService.service_type),
            joinedload(models.Member.services).joinedload(models.MemberService.service_type),
        )
        .filter(models.Member.qr_token == qr_token)
        .first()
    )
    if not member:
        raise HTTPException(status_code=404, detail="Member not found for this QR token")
    return member


@router.post("/deploy-service", response_model=schemas.ServiceLogOut)
def deploy_service(
    payload: schemas.DeployServiceRequest,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    # When a pet is specified, consume from pet-level sessions first
    if payload.pet_id:
        pet_service = (
            db.query(models.PetService)
            .options(joinedload(models.PetService.service_type))
            .filter(
                models.PetService.pet_id == payload.pet_id,
                models.PetService.service_type_id == payload.service_type_id,
            )
            .first()
        )
        if pet_service:
            if pet_service.remaining_sessions <= 0:
                raise HTTPException(status_code=400, detail="No remaining sessions for this service on this pet")
            pet_service.used_sessions += 1
            log = models.ServiceLog(
                member_id=payload.member_id,
                pet_id=payload.pet_id,
                service_type_id=payload.service_type_id,
                logged_by_admin_id=current_user.id,
                notes=payload.notes,
            )
            db.add(log)
            db.flush()
            _award_service_points(db, payload.member_id, pet_service.service_type.name, log.id)
            db.commit()
            db.refresh(log)
            return log

    # Fall back to member-level sessions
    member_service = (
        db.query(models.MemberService)
        .options(joinedload(models.MemberService.service_type))
        .filter(
            models.MemberService.member_id == payload.member_id,
            models.MemberService.service_type_id == payload.service_type_id,
        )
        .first()
    )
    if not member_service:
        raise HTTPException(status_code=404, detail="Member does not have this service")
    if member_service.remaining_sessions <= 0:
        raise HTTPException(status_code=400, detail="No remaining sessions for this service")

    member_service.used_sessions += 1

    log = models.ServiceLog(
        member_id=payload.member_id,
        pet_id=payload.pet_id,
        service_type_id=payload.service_type_id,
        logged_by_admin_id=current_user.id,
        notes=payload.notes,
    )
    db.add(log)
    db.flush()
    _award_service_points(db, payload.member_id, member_service.service_type.name, log.id)
    db.commit()
    db.refresh(log)
    return log


@router.post("/assign-service", response_model=schemas.MemberServiceOut, status_code=201)
def assign_service(
    payload: schemas.AssignServiceRequest,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    existing = db.query(models.MemberService).filter(
        models.MemberService.member_id == payload.member_id,
        models.MemberService.service_type_id == payload.service_type_id,
    ).first()

    if existing:
        existing.total_sessions += payload.total_sessions
        if payload.expires_at:
            existing.expires_at = payload.expires_at
        db.commit()
        db.refresh(existing)
        return existing

    ms = models.MemberService(
        member_id=payload.member_id,
        service_type_id=payload.service_type_id,
        total_sessions=payload.total_sessions,
        expires_at=payload.expires_at,
    )
    db.add(ms)
    db.commit()
    db.refresh(ms)
    return ms


@router.get("/members", response_model=list[schemas.MemberSummary])
def list_members(
    skip: int = 0,
    limit: int = 50,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.Member)
        .options(
            joinedload(models.Member.user),
            joinedload(models.Member.pets).joinedload(models.Pet.pet_services).joinedload(models.PetService.service_type),
            joinedload(models.Member.services).joinedload(models.MemberService.service_type),
        )
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.post("/members", response_model=schemas.MemberOut, status_code=201)
def create_member_admin(
    payload: schemas.AdminMemberCreate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    if db.query(models.User).filter(models.User.email == payload.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    user = models.User(
        email=payload.email,
        password_hash=auth_utils.hash_password(payload.password),
        role=models.UserRole.member,
    )
    db.add(user)
    db.flush()

    member = models.Member(
        user_id=user.id,
        first_name=payload.first_name,
        last_name=payload.last_name,
        phone=payload.phone,
        address=payload.address,
    )
    db.add(member)
    db.commit()
    db.refresh(member)
    return member


@router.put("/members/{member_id}", response_model=schemas.MemberOut)
def update_member_admin(
    member_id: str,
    payload: schemas.MemberUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    member = (
        db.query(models.Member)
        .options(
            joinedload(models.Member.pets),
            joinedload(models.Member.services).joinedload(models.MemberService.service_type),
        )
        .filter(models.Member.id == member_id)
        .first()
    )
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(member, field, value)
    db.commit()
    db.refresh(member)
    return member


@router.put("/members/{member_id}/direct-pay", response_model=schemas.MemberOut)
def update_member_direct_pay(
    member_id: str,
    payload: schemas.MemberDirectPayUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Restrict, force-allow, or reset one member's direct-to-provider access.

    Separate from update_member_admin because that endpoint applies
    `exclude_none=True` — which cannot express "set this back to NULL", the
    value that means "follow the global switch". Here None is a real choice.
    """
    member = (
        db.query(models.Member)
        .options(
            joinedload(models.Member.pets),
            joinedload(models.Member.services).joinedload(models.MemberService.service_type),
        )
        .filter(models.Member.id == member_id)
        .first()
    )
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")

    member.direct_pay_enabled = payload.direct_pay_enabled
    member.direct_pay_note = (payload.direct_pay_note or "").strip() or None
    member.direct_pay_updated_by_admin_id = current_user.id
    member.direct_pay_updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(member)
    return member


@router.delete("/members/{member_id}", status_code=204)
def delete_member_admin(
    member_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    member = db.query(models.Member).filter(models.Member.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    user = db.query(models.User).filter(models.User.id == member.user_id).first()
    db.delete(member)
    if user:
        db.delete(user)
    db.commit()


@router.put("/members/{member_id}/founding", response_model=schemas.MemberOut)
def set_member_founding(
    member_id: str,
    payload: schemas.FoundingStatusUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    member = (
        db.query(models.Member)
        .options(
            joinedload(models.Member.pets),
            joinedload(models.Member.services).joinedload(models.MemberService.service_type),
        )
        .filter(models.Member.id == member_id)
        .first()
    )
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    member.is_founding = payload.is_founding
    db.commit()
    db.refresh(member)
    return member


@router.get("/service-types", response_model=list[schemas.ServiceTypeOut])
def list_service_types(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    return db.query(models.ServiceType).all()


@router.post("/service-types", response_model=schemas.ServiceTypeOut, status_code=201)
def create_service_type(
    name: str,
    description: str = None,
    icon: str = "pets",
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    st = models.ServiceType(name=name, description=description, icon=icon)
    db.add(st)
    db.commit()
    db.refresh(st)
    return st


@router.get("/plans", response_model=list[schemas.PlanOut])
def list_plans_admin(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    return db.query(models.Plan).order_by(models.Plan.sort_order).all()


@router.post("/plans", response_model=schemas.PlanOut, status_code=201)
def create_plan(
    payload: schemas.PlanCreate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    plan = models.Plan(**payload.model_dump())
    db.add(plan)
    db.commit()
    db.refresh(plan)
    return plan


def _apply_service_caps(
    db: Session,
    plan: models.Plan,
    caps: list[dict],
    actor: models.User,
) -> None:
    """Apply reimbursement-cap / session edits to the plan's categories, creating a
    plan_services row when the category isn't on the plan yet, and record an audit
    entry for each actual change.

    Adding a category takes effect immediately for reimbursement (the wallet and
    claim eligibility read plan_services live), but session credits are granted
    only at activation/renewal — existing pets on the plan are NOT backfilled here.
    """
    rows = {ps.service_type_id: ps for ps in plan.plan_services}
    for cap in caps:
        service_type_id = cap["service_type_id"]
        new_val = cap["reimbursement_cap_centavos"]
        new_sessions = cap.get("sessions")
        ps = rows.get(service_type_id)

        if ps is None:
            # New category on this plan — validate the ServiceType exists first.
            exists = (
                db.query(models.ServiceType)
                .filter(models.ServiceType.id == service_type_id)
                .first()
            )
            if not exists:
                raise HTTPException(
                    status_code=422,
                    detail="A reimbursement cap targets a service category that doesn't exist.",
                )
            sessions = new_sessions or 0
            ps = models.PlanService(
                plan_id=plan.id,
                service_type_id=service_type_id,
                sessions=sessions,
                reimbursement_cap_centavos=new_val,
            )
            db.add(ps)
            rows[service_type_id] = ps
            db.add(
                models.PlanChangeEvent(
                    plan_id=plan.id,
                    service_type_id=service_type_id,
                    field="category_added",
                    from_value=None,
                    to_value=f"sessions={sessions};cap={new_val}",
                    actor_user_id=actor.id,
                )
            )
            continue

        # Existing category — update the cap and/or sessions, auditing each change.
        old_val = ps.reimbursement_cap_centavos or 0
        if old_val != new_val:
            ps.reimbursement_cap_centavos = new_val
            db.add(
                models.PlanChangeEvent(
                    plan_id=plan.id,
                    service_type_id=service_type_id,
                    field="reimbursement_cap_centavos",
                    from_value=str(old_val),
                    to_value=str(new_val),
                    actor_user_id=actor.id,
                )
            )
        if new_sessions is not None and new_sessions != (ps.sessions or 0):
            old_sessions = ps.sessions or 0
            ps.sessions = new_sessions
            db.add(
                models.PlanChangeEvent(
                    plan_id=plan.id,
                    service_type_id=service_type_id,
                    field="sessions",
                    from_value=str(old_sessions),
                    to_value=str(new_sessions),
                    actor_user_id=actor.id,
                )
            )


@router.put("/plans/{plan_id}", response_model=schemas.PlanOut)
def update_plan(
    plan_id: str,
    payload: schemas.PlanUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    plan = db.query(models.Plan).filter(models.Plan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    data = payload.model_dump(exclude_unset=True)
    # service_caps isn't a Plan column — pull it out and apply to plan_services rows.
    service_caps = data.pop("service_caps", None)
    # Audit wallet changes (money config) before applying them — one event per
    # pool that changed.
    for field in ("reimbursement_wallet_centavos", "emergency_wallet_centavos"):
        new_wallet = data.get(field)
        old_wallet = getattr(plan, field) or 0
        if new_wallet is not None and new_wallet != old_wallet:
            db.add(
                models.PlanChangeEvent(
                    plan_id=plan.id,
                    service_type_id=None,
                    field=field,
                    from_value=str(old_wallet),
                    to_value=str(new_wallet),
                    actor_user_id=current_user.id,
                )
            )
    for k, v in data.items():
        setattr(plan, k, v)
    if service_caps:
        _apply_service_caps(db, plan, service_caps, current_user)

    db.commit()
    db.refresh(plan)
    return plan


@router.delete("/plans/{plan_id}", status_code=204)
def delete_plan(
    plan_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    plan = db.query(models.Plan).filter(models.Plan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    db.delete(plan)
    db.commit()


@router.get("/clinic-partners", response_model=list[schemas.ClinicPartnerOut])
def list_clinic_partners(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.ClinicPartner)
        .options(joinedload(models.ClinicPartner.user))
        .order_by(models.ClinicPartner.created_at.desc())
        .all()
    )


@router.post("/clinic-partners", response_model=schemas.ClinicPartnerOut, status_code=201)
def create_clinic_partner(
    payload: schemas.ClinicPartnerCreate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    if db.query(models.User).filter(models.User.email == payload.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    user = models.User(
        email=payload.email,
        password_hash=auth_utils.hash_password(payload.password),
        role=models.UserRole.clinic,
    )
    db.add(user)
    db.flush()

    clinic = models.ClinicPartner(
        user_id=user.id,
        clinic_name=payload.clinic_name,
        phone=payload.phone,
        address=payload.address,
    )
    db.add(clinic)
    db.commit()
    db.refresh(clinic)
    db.refresh(user)
    return clinic


@router.put("/clinic-partners/{clinic_id}", response_model=schemas.ClinicPartnerOut)
def update_clinic_partner(
    clinic_id: str,
    payload: schemas.ClinicPartnerUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    clinic = db.query(models.ClinicPartner).filter(models.ClinicPartner.id == clinic_id).first()
    if not clinic:
        raise HTTPException(status_code=404, detail="Clinic partner not found")
    if payload.clinic_name is not None:
        clinic.clinic_name = payload.clinic_name
    if payload.phone is not None:
        clinic.phone = payload.phone or None
    if payload.address is not None:
        clinic.address = payload.address or None
    db.commit()
    db.refresh(clinic)
    return clinic


@router.delete("/clinic-partners/{clinic_id}", status_code=204)
def delete_clinic_partner(
    clinic_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    clinic = db.query(models.ClinicPartner).filter(models.ClinicPartner.id == clinic_id).first()
    if not clinic:
        raise HTTPException(status_code=404, detail="Clinic partner not found")
    user = db.query(models.User).filter(models.User.id == clinic.user_id).first()
    db.delete(clinic)
    if user:
        db.delete(user)
    db.commit()


# --- Reimbursement Providers (verified direct-pay payees) ---
# Deliberately unrelated to ClinicPartner above — no linked login account, just
# identity + payout details for the "MetroPaws pays the provider directly"
# reimbursement option. See models.ReimbursementProvider / routers/reimbursements.py.

@router.get("/reimbursement-providers", response_model=list[schemas.ReimbursementProviderOut])
def list_reimbursement_providers_admin(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.ReimbursementProvider)
        .order_by(models.ReimbursementProvider.name)
        .all()
    )


@router.post("/reimbursement-providers", response_model=schemas.ReimbursementProviderOut, status_code=201)
def create_reimbursement_provider(
    payload: schemas.ReimbursementProviderCreate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    provider = models.ReimbursementProvider(**payload.model_dump())
    db.add(provider)
    db.commit()
    db.refresh(provider)
    return provider


@router.put("/reimbursement-providers/{provider_id}", response_model=schemas.ReimbursementProviderOut)
def update_reimbursement_provider(
    provider_id: str,
    payload: schemas.ReimbursementProviderUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    provider = (
        db.query(models.ReimbursementProvider)
        .filter(models.ReimbursementProvider.id == provider_id)
        .first()
    )
    if not provider:
        raise HTTPException(status_code=404, detail="Provider not found")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(provider, field, value)
    db.commit()
    db.refresh(provider)
    return provider


@router.delete("/reimbursement-providers/{provider_id}", status_code=204)
def delete_reimbursement_provider(
    provider_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    provider = (
        db.query(models.ReimbursementProvider)
        .filter(models.ReimbursementProvider.id == provider_id)
        .first()
    )
    if not provider:
        raise HTTPException(status_code=404, detail="Provider not found")
    has_claims = (
        db.query(models.Reimbursement)
        .filter(models.Reimbursement.provider_id == provider_id)
        .first()
        is not None
    )
    if has_claims:
        raise HTTPException(
            status_code=400,
            detail="Can't delete a provider with existing claims — deactivate it instead.",
        )
    db.delete(provider)
    db.commit()


# --- Admin Pet Management ---

@router.put("/members/{member_id}/pets/{pet_id}", response_model=schemas.PetOut)
def update_pet_admin(
    member_id: str,
    pet_id: str,
    payload: schemas.PetUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    pet = (
        db.query(models.Pet)
        .options(joinedload(models.Pet.pet_services).joinedload(models.PetService.service_type))
        .filter(models.Pet.id == pet_id, models.Pet.member_id == member_id)
        .first()
    )
    if not pet:
        raise HTTPException(status_code=404, detail="Pet not found")
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(pet, field, value)
    db.commit()
    db.refresh(pet)
    return pet


@router.delete("/members/{member_id}/pets/{pet_id}", status_code=204)
def delete_pet_admin(
    member_id: str,
    pet_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    pet = db.query(models.Pet).filter(
        models.Pet.id == pet_id,
        models.Pet.member_id == member_id,
    ).first()
    if not pet:
        raise HTTPException(status_code=404, detail="Pet not found")
    db.delete(pet)
    db.commit()


@router.get("/bookings", response_model=list[schemas.AdminBookingOut])
def list_bookings(
    status: Optional[str] = Query(None),
    skip: int = 0,
    limit: int = 100,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    q = (
        db.query(models.Booking)
        .options(
            joinedload(models.Booking.service_type),
            joinedload(models.Booking.member),
            joinedload(models.Booking.clinic),
        )
    )
    if status:
        try:
            q = q.filter(models.Booking.status == models.BookingStatus(status))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid status value")
    return (
        q.order_by(models.Booking.booking_date.asc(), models.Booking.created_at.asc())
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.put("/bookings/{booking_id}/confirm", response_model=schemas.AdminBookingOut)
def confirm_booking(
    booking_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    booking = (
        db.query(models.Booking)
        .options(
            joinedload(models.Booking.service_type),
            joinedload(models.Booking.member),
            joinedload(models.Booking.clinic),
        )
        .filter(models.Booking.id == booking_id)
        .first()
    )
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.status != models.BookingStatus.pending:
        raise HTTPException(status_code=400, detail="Only pending bookings can be confirmed")

    # Deduct a session if the member now has credit (e.g. after payment)
    member_service = db.query(models.MemberService).filter(
        models.MemberService.member_id == booking.member_id,
        models.MemberService.service_type_id == booking.service_type_id,
    ).first()
    if member_service and member_service.remaining_sessions > 0:
        member_service.used_sessions += 1
        booking.credit_used = True

    booking.status = models.BookingStatus.confirmed
    db.commit()
    db.refresh(booking)
    return booking


@router.put("/bookings/{booking_id}/cancel", response_model=schemas.AdminBookingOut)
def cancel_booking(
    booking_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    booking = (
        db.query(models.Booking)
        .options(
            joinedload(models.Booking.service_type),
            joinedload(models.Booking.member),
            joinedload(models.Booking.clinic),
        )
        .filter(models.Booking.id == booking_id)
        .first()
    )
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.status == models.BookingStatus.cancelled:
        raise HTTPException(status_code=400, detail="Booking is already cancelled")

    # Restore session credit if it was used
    if booking.credit_used:
        member_service = db.query(models.MemberService).filter(
            models.MemberService.member_id == booking.member_id,
            models.MemberService.service_type_id == booking.service_type_id,
        ).first()
        if member_service and member_service.used_sessions > 0:
            member_service.used_sessions -= 1
        booking.credit_used = False

    booking.status = models.BookingStatus.cancelled
    db.commit()
    db.refresh(booking)
    return booking


@router.get("/logs", response_model=list[schemas.ServiceLogOut])
def get_logs(
    member_id: str = None,
    skip: int = 0,
    limit: int = 100,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    q = db.query(models.ServiceLog).options(joinedload(models.ServiceLog.service_type))
    if member_id:
        q = q.filter(models.ServiceLog.member_id == member_id)
    return q.order_by(models.ServiceLog.logged_at.desc()).offset(skip).limit(limit).all()


@router.get("/analytics/founding-location")
def founding_location_analytics(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    from collections import defaultdict

    reservations = db.query(models.FoundingReservation).all()

    counts: dict = defaultdict(lambda: {"total": 0, "approved": 0, "pending": 0, "rejected": 0})
    for r in reservations:
        brgy = (r.barangay or "").strip() or "Unknown"
        status_key = r.status.value if hasattr(r.status, "value") else str(r.status)
        counts[brgy]["total"] += 1
        if status_key in counts[brgy]:
            counts[brgy][status_key] += 1

    return sorted(
        [{"barangay": k, **v} for k, v in counts.items()],
        key=lambda x: (-x["approved"], -x["total"]),
    )


@router.get("/analytics/overview")
def analytics_overview(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Business KPIs for the management dashboard: membership, revenue, plan
    mix, claims/payouts, and benefit utilization. All figures are derived
    read-only from live data. Revenue is whole pesos (payments); claim payouts
    are stored in centavos and returned as whole pesos."""

    total_members = db.query(func.count(models.Member.id)).scalar() or 0
    founding_members = (
        db.query(func.count(models.Member.id))
        .filter(models.Member.is_founding == True)  # noqa: E712
        .scalar()
        or 0
    )
    # An activated membership = a pet whose plan has been activated.
    active_memberships = (
        db.query(func.count(models.Pet.id))
        .filter(models.Pet.plan_activated_at.isnot(None))
        .scalar()
        or 0
    )

    plan_rows = (
        db.query(models.Pet.plan_type, func.count(models.Pet.id))
        .filter(models.Pet.plan_activated_at.isnot(None))
        .group_by(models.Pet.plan_type)
        .all()
    )
    plan_mix = [{"plan": plan or "Unknown", "count": count} for plan, count in plan_rows]

    revenue_php = (
        db.query(func.coalesce(func.sum(models.Payment.amount_php), 0))
        .filter(models.Payment.status == models.PaymentStatus.paid)
        .scalar()
        or 0
    )
    paid_payments = (
        db.query(func.count(models.Payment.id))
        .filter(models.Payment.status == models.PaymentStatus.paid)
        .scalar()
        or 0
    )

    claim_rows = (
        db.query(models.Reimbursement.status, func.count(models.Reimbursement.id))
        .group_by(models.Reimbursement.status)
        .all()
    )
    claims_by_status: dict = {}
    for status_value, count in claim_rows:
        key = status_value.value if hasattr(status_value, "value") else str(status_value)
        claims_by_status[key] = count
    total_claims = sum(claims_by_status.values())
    pending_review = (
        claims_by_status.get("pending", 0)
        + claims_by_status.get("under_review", 0)
        + claims_by_status.get("needs_info", 0)
    )

    payout_centavos = (
        db.query(func.coalesce(func.sum(models.Reimbursement.approved_amount_centavos), 0))
        .filter(models.Reimbursement.status == models.ReimbursementStatus.paid)
        .scalar()
        or 0
    )

    total_sessions = db.query(func.coalesce(func.sum(models.PetService.total_sessions), 0)).scalar() or 0
    used_sessions = db.query(func.coalesce(func.sum(models.PetService.used_sessions), 0)).scalar() or 0
    used_pct = round((used_sessions / total_sessions) * 100, 1) if total_sessions else 0.0

    partner_clinics = db.query(func.count(models.ClinicPartner.id)).scalar() or 0

    return {
        "members": {
            "total": total_members,
            "founding": founding_members,
            "active_memberships": active_memberships,
        },
        "revenue": {
            "total_php": int(revenue_php),
            "paid_payments": paid_payments,
        },
        "plan_mix": plan_mix,
        "claims": {
            "total": total_claims,
            "by_status": claims_by_status,
            "pending_review": pending_review,
            "payout_total_php": round(payout_centavos / 100),
        },
        "utilization": {
            "total_sessions": total_sessions,
            "used_sessions": used_sessions,
            "used_pct": used_pct,
        },
        "partner_clinics": partner_clinics,
    }


@router.get("/payments", response_model=list[schemas.AdminPaymentOut])
def list_payments(
    status: Optional[models.PaymentStatus] = Query(default=None),
    limit: int = Query(default=200, ge=1, le=1000),
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Every payment attempt with who made it — the drill-down behind the
    dashboard's Revenue Collected figure, so admins can reconcile against the
    PayMongo dashboard without leaving the app."""
    query = (
        db.query(models.Payment)
        .options(
            joinedload(models.Payment.member).joinedload(models.Member.user),
            joinedload(models.Payment.plan),
            joinedload(models.Payment.pet),
        )
        .order_by(models.Payment.created_at.desc())
    )
    if status is not None:
        query = query.filter(models.Payment.status == status)
    payments = query.limit(limit).all()

    return [
        schemas.AdminPaymentOut(
            id=p.id,
            member_id=p.member_id,
            member_first_name=p.member.first_name if p.member else "",
            member_last_name=p.member.last_name if p.member else "",
            member_email=p.member.email if p.member else None,
            pet_name=p.pet.name if p.pet else None,
            plan_name=p.plan.name if p.plan else None,
            amount_php=p.amount_php,
            currency=p.currency,
            status=p.status.value,
            provider=p.provider,
            provider_payment_id=p.provider_payment_id,
            created_at=p.created_at,
            paid_at=p.paid_at,
        )
        for p in payments
    ]


@router.get("/payments/{payment_id}/invoice")
def get_payment_invoice(
    payment_id: str,
    download: bool = Query(default=False),
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Return the branded PDF receipt for a paid payment so an admin can view or
    download it. ``?download=true`` forces a save dialog; otherwise it opens
    inline in the browser's PDF viewer (which itself offers a download)."""
    payment = (
        db.query(models.Payment)
        .filter(models.Payment.id == payment_id)
        .first()
    )
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if payment.status != models.PaymentStatus.paid:
        raise HTTPException(
            status_code=400,
            detail="Only paid payments have a receipt.",
        )

    try:
        pdf_bytes, _inv_no, filename = invoice_utils.build_receipt_pdf(db, payment)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception:
        raise HTTPException(status_code=500, detail="Could not generate the receipt PDF.")

    disposition = "attachment" if download else "inline"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'{disposition}; filename="{filename}"'},
    )


@router.post("/payments/{payment_id}/resend-invoice")
def resend_payment_invoice(
    payment_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Regenerate and re-email a paid payment's PDF receipt to the member.

    The same receipt is emailed automatically when a payment is confirmed; this
    lets an admin resend it (member deleted the email, wrong inbox, etc.). Only
    paid payments have a receipt. Unlike the auto path, failures surface to the
    operator so a misconfigured SMTP / missing email is visible."""
    payment = (
        db.query(models.Payment)
        .filter(models.Payment.id == payment_id)
        .first()
    )
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if payment.status != models.PaymentStatus.paid:
        raise HTTPException(
            status_code=400,
            detail="Only paid payments have a receipt to send.",
        )

    try:
        invoice_no = invoice_utils.generate_and_send(db, payment)
    except ValueError as e:
        # Expected, actionable problems (no member email, etc.).
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.exception("Resend receipt failed for payment %s", payment_id)
        raise HTTPException(
            status_code=502,
            detail=f"Could not send the receipt email ({type(e).__name__}: {e}). "
                   "Check the mail (SMTP) configuration and try again.",
        )

    return {
        "sent": True,
        "invoice_no": invoice_no,
        "email": payment.member.email if payment.member else None,
    }


@router.get("/analytics/top-providers")
def top_providers_analytics(
    service_type_id: Optional[str] = Query(default=None),
    limit: Optional[int] = Query(default=None, ge=1, le=500),
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Where members spend out-of-pocket: reimbursement claims grouped by the
    provider name written on the claim (case/space-insensitive), ranked by claim
    count. Omitting ``limit`` returns every clinic, which feeds the dashboard's
    partnership-prospecting directory. Money is returned as whole pesos to match
    /analytics/overview."""
    from sqlalchemy import case

    norm = func.lower(func.trim(models.Reimbursement.provider_name))
    approved_states = (
        models.ReimbursementStatus.approved,
        models.ReimbursementStatus.paid,
    )
    approved_flag = case(
        (models.Reimbursement.status.in_(approved_states), 1),
        else_=0,
    )
    approved_amount = case(
        (
            models.Reimbursement.status.in_(approved_states),
            func.coalesce(models.Reimbursement.approved_amount_centavos, 0),
        ),
        else_=0,
    )

    q = db.query(
        func.max(models.Reimbursement.provider_name).label("provider"),
        func.count(models.Reimbursement.id).label("claims"),
        func.count(func.distinct(models.Reimbursement.member_id)).label("members"),
        func.coalesce(func.sum(approved_flag), 0).label("approved_claims"),
        func.coalesce(func.sum(models.Reimbursement.claimed_amount_centavos), 0).label("claimed_centavos"),
        func.coalesce(func.sum(approved_amount), 0).label("approved_centavos"),
        func.max(models.Reimbursement.service_date).label("last_visit"),
    )
    if service_type_id:
        q = q.filter(models.Reimbursement.service_type_id == service_type_id)

    q = q.group_by(norm).order_by(func.count(models.Reimbursement.id).desc())
    if limit is not None:
        q = q.limit(limit)
    rows = q.all()

    return [
        {
            "provider": r.provider,
            "claims": r.claims,
            "members": int(r.members),
            "approved_claims": int(r.approved_claims),
            "claimed_php": round(r.claimed_centavos / 100),
            "approved_php": round(r.approved_centavos / 100),
            "last_visit": r.last_visit.isoformat() if r.last_visit else None,
        }
        for r in rows
    ]


@router.post("/paw-points/award", status_code=201)
def award_paw_points(
    payload: schemas.PawAwardRequest,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    member = db.query(models.Member).filter(models.Member.id == payload.member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    awarded = award_points(
        db,
        member_id=payload.member_id,
        activity_type="admin_manual_award",
        points_override=payload.points,
        notes=payload.notes,
    )
    db.commit()
    return {"member_id": payload.member_id, "points_awarded": awarded}


# --- Reimbursements (admin review) ---

def _reimbursement_query(db: Session):
    return db.query(models.Reimbursement).options(
        joinedload(models.Reimbursement.service_type),
        joinedload(models.Reimbursement.pet),
        joinedload(models.Reimbursement.member).joinedload(models.Member.user),
        joinedload(models.Reimbursement.provider),
        selectinload(models.Reimbursement.events),
    )


@router.get("/reimbursements", response_model=list[schemas.AdminReimbursementOut])
def list_reimbursements(
    status: Optional[str] = Query(None),
    member_id: Optional[str] = Query(None),
    skip: int = 0,
    limit: int = 100,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    # DPA access log: record admin access to members' financial data.
    print(f"[audit] admin={current_user.id} accessed reimbursements "
          f"(status={status}, member_id={member_id})")
    q = _reimbursement_query(db)
    if status:
        try:
            q = q.filter(models.Reimbursement.status == models.ReimbursementStatus(status))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid status value")
    if member_id:
        q = q.filter(models.Reimbursement.member_id == member_id)
    return (
        q.order_by(models.Reimbursement.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.put("/reimbursements/{reimbursement_id}/review", response_model=schemas.AdminReimbursementOut)
def review_reimbursement(
    reimbursement_id: str,
    payload: schemas.ReimbursementReviewRequest,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    # Lock the claim row for the duration of the decision.
    claim = (
        db.query(models.Reimbursement)
        .filter(models.Reimbursement.id == reimbursement_id)
        .with_for_update()
        .first()
    )
    if not claim:
        raise HTTPException(status_code=404, detail="Claim not found")
    if claim.status == models.ReimbursementStatus.paid:
        raise HTTPException(status_code=400, detail="Paid claims can't be modified.")

    valid = {"under_review", "needs_info", "approved", "rejected"}
    if payload.status not in valid:
        raise HTTPException(status_code=422, detail=f"Status must be one of {sorted(valid)}")
    new_status = models.ReimbursementStatus(payload.status)

    note = (payload.admin_notes or "").strip()
    if new_status in (models.ReimbursementStatus.needs_info, models.ReimbursementStatus.rejected) and not note:
        raise HTTPException(
            status_code=422,
            detail="A note is required when requesting more info or rejecting a claim.",
        )

    if new_status == models.ReimbursementStatus.approved:
        if payload.approved_amount_centavos is None or payload.approved_amount_centavos <= 0:
            raise HTTPException(status_code=422, detail="approved_amount_centavos is required to approve.")
        pet = db.query(models.Pet).filter(models.Pet.id == claim.pet_id).first()
        # Approve against the pool this claim's category draws from.
        emergency = rutils.is_emergency_category(
            claim.service_type.name if claim.service_type else None
        )
        wallet = (
            rutils.plan_emergency_wallet_centavos(db, pet.plan_id if pet else None)
            if emergency
            else rutils.plan_wallet_centavos(db, pet.plan_id if pet else None)
        )
        # Lock the pet's claim set so two approvals can't overspend the wallet.
        prev_used, _prev_pending, emg_used, _emg_pending = rutils.wallet_usage(
            db, pet, exclude_id=claim.id, lock=True
        )
        used = emg_used if emergency else prev_used
        remaining = wallet - used
        if payload.approved_amount_centavos > remaining:
            wallet_name = "Emergency Wallet" if emergency else "Preventive Wellness Wallet"
            raise HTTPException(
                status_code=400,
                detail=f"Approved amount exceeds the remaining {wallet_name} (₱{max(0, remaining) // 100:,} left).",
            )
        claim.approved_amount_centavos = payload.approved_amount_centavos

    prev = claim.status
    claim.status = new_status
    if payload.admin_notes is not None:
        claim.admin_notes = payload.admin_notes
    claim.reviewed_by_admin_id = current_user.id
    claim.reviewed_at = datetime.now(timezone.utc)
    db.add(
        models.ReimbursementEvent(
            reimbursement_id=claim.id,
            from_status=prev.value,
            to_status=new_status.value,
            actor_user_id=current_user.id,
            note=note or None,
        )
    )
    db.commit()
    db.refresh(claim)

    if new_status in (
        models.ReimbursementStatus.approved,
        models.ReimbursementStatus.rejected,
        models.ReimbursementStatus.needs_info,
    ):
        rutils.notify_status(db, claim)

    return _reimbursement_query(db).filter(models.Reimbursement.id == claim.id).first()


@router.put("/reimbursements/{reimbursement_id}/mark-paid", response_model=schemas.AdminReimbursementOut)
def mark_reimbursement_paid(
    reimbursement_id: str,
    payload: schemas.MarkPaidRequest,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    reference = (payload.payment_reference or "").strip()
    if not reference:
        raise HTTPException(
            status_code=422,
            detail="A payment reference (GCash/bank transaction no.) is required to mark paid.",
        )

    claim = (
        db.query(models.Reimbursement)
        .filter(models.Reimbursement.id == reimbursement_id)
        .first()
    )
    if not claim:
        raise HTTPException(status_code=404, detail="Claim not found")
    if claim.status != models.ReimbursementStatus.approved:
        raise HTTPException(status_code=400, detail="Only approved claims can be marked paid.")

    # Segregation of duties: the approver can't also release payment (when enabled).
    if _ENFORCE_DUAL_CONTROL and claim.reviewed_by_admin_id == current_user.id:
        raise HTTPException(
            status_code=403,
            detail="A different admin must release payment (segregation of duties).",
        )

    prev = claim.status
    claim.status = models.ReimbursementStatus.paid
    claim.paid_by_admin_id = current_user.id
    claim.paid_at = datetime.now(timezone.utc)
    claim.paid_reference = reference
    if payload.admin_notes:
        claim.admin_notes = payload.admin_notes
    db.add(
        models.ReimbursementEvent(
            reimbursement_id=claim.id,
            from_status=prev.value,
            to_status=models.ReimbursementStatus.paid.value,
            actor_user_id=current_user.id,
            note=f"Reimbursement released (ref: {reference})",
        )
    )
    db.commit()
    db.refresh(claim)

    rutils.notify_status(db, claim)
    return _reimbursement_query(db).filter(models.Reimbursement.id == claim.id).first()
