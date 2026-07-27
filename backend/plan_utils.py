from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

import models


_FOUNDING_BONUS = [
    ("Grooming", 1),
    ("General Consultation", 1),
]

_PREMIUM_TIERS = {"Deluxe", "Premium"}


def grant_plan_to_pet(db: Session, pet: models.Pet, plan: models.Plan, member: models.Member) -> None:
    """Assign a plan to a pet, REPLACING any previous benefits (client decision
    2026-07-27, upgrade/renewal rules): every grant — first activation, upgrade,
    or renewal — resets the pet to exactly the new plan's sessions with a fresh
    1-year expiry. Nothing tops up or rolls over; unused sessions from the old
    term are forfeited ("no more, no less" than the plan). Wallets reset the
    same way because reimbursement_utils.wallet_usage windows claims on the
    plan_activated_at stamped here. ServiceLog rows are untouched — they remain
    the historical audit of past terms.

    Also tracks the member's previous_plan_tier for 10% discount eligibility:
    if a member has ever had Deluxe or Premium on any pet, they qualify for 10% off
    additional a-la-carte services when on the Standard tier.
    """
    if plan.name in _PREMIUM_TIERS:
        member.previous_plan_tier = plan.name

    pet.plan_id = plan.id
    pet.plan_type = plan.name
    pet.plan_activated_at = datetime.now(timezone.utc)

    # Replace semantics: wipe the old benefit rows, then rebuild from the plan.
    # The flush respects uq_pet_service before the fresh inserts below; the
    # expire drops the now-stale pet.pet_services collection from the session
    # (bulk delete does not sync loaded relationships).
    db.query(models.PetService).filter(models.PetService.pet_id == pet.id).delete()
    db.flush()
    db.expire(pet, ["pet_services"])

    expires_at = datetime.now(timezone.utc) + timedelta(days=365)
    plan_services = (
        db.query(models.PlanService)
        .filter(models.PlanService.plan_id == plan.id)
        .all()
    )
    for ps in plan_services:
        if ps.sessions <= 0:
            continue
        db.add(
            models.PetService(
                pet_id=pet.id,
                service_type_id=ps.service_type_id,
                total_sessions=ps.sessions,
                expires_at=expires_at,
            )
        )

    # Flush so the founding-bonus loop below can find the records just added above.
    # The session uses autoflush=False, so without this explicit flush the bonus
    # queries would miss pending inserts and create duplicate rows.
    db.flush()

    if getattr(member, "is_founding", False):
        for svc_name, bonus in _FOUNDING_BONUS:
            svc_type = (
                db.query(models.ServiceType)
                .filter(models.ServiceType.name == svc_name)
                .first()
            )
            if not svc_type:
                continue
            existing = (
                db.query(models.PetService)
                .filter(
                    models.PetService.pet_id == pet.id,
                    models.PetService.service_type_id == svc_type.id,
                )
                .first()
            )
            if existing:
                existing.total_sessions += bonus
            else:
                db.add(
                    models.PetService(
                        pet_id=pet.id,
                        service_type_id=svc_type.id,
                        total_sessions=bonus,
                        expires_at=expires_at,
                    )
                )


def grant_plan_to_member(db: Session, member: models.Member, plan: models.Plan) -> None:
    """Assign a plan and create/top-up MemberService records with a 1-year expiry."""
    member.plan_id = plan.id
    member.plan_type = plan.name

    expires_at = datetime.now(timezone.utc) + timedelta(days=365)
    plan_services = (
        db.query(models.PlanService)
        .filter(models.PlanService.plan_id == plan.id)
        .all()
    )
    for ps in plan_services:
        if ps.sessions <= 0:
            continue
        existing = (
            db.query(models.MemberService)
            .filter(
                models.MemberService.member_id == member.id,
                models.MemberService.service_type_id == ps.service_type_id,
            )
            .first()
        )
        if existing:
            existing.total_sessions += ps.sessions
            if not existing.expires_at or existing.expires_at < expires_at:
                existing.expires_at = expires_at
        else:
            db.add(
                models.MemberService(
                    member_id=member.id,
                    service_type_id=ps.service_type_id,
                    total_sessions=ps.sessions,
                    expires_at=expires_at,
                )
            )

    if getattr(member, "is_founding", False):
        for svc_name, bonus in _FOUNDING_BONUS:
            svc_type = (
                db.query(models.ServiceType)
                .filter(models.ServiceType.name == svc_name)
                .first()
            )
            if not svc_type:
                continue
            existing = (
                db.query(models.MemberService)
                .filter(
                    models.MemberService.member_id == member.id,
                    models.MemberService.service_type_id == svc_type.id,
                )
                .first()
            )
            if existing:
                existing.total_sessions += bonus
            else:
                db.add(
                    models.MemberService(
                        member_id=member.id,
                        service_type_id=svc_type.id,
                        total_sessions=bonus,
                        expires_at=expires_at,
                    )
                )
