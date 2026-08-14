"""QR scan, service deployment and assignment, service types, and the
service log — the counter-side admin actions performed on a member's visit."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

import models, schemas, auth as auth_utils
from database import get_db
from domain.paw_points_utils import award_points

router = APIRouter(tags=["admin"])


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
