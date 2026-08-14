"""Member records: listing, admin-side creation and edits, founding status,
and the per-member direct-pay override."""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

import models, schemas, auth as auth_utils
from database import get_db

router = APIRouter(tags=["admin"])


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
