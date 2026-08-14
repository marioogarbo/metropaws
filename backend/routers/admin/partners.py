"""Clinic partners — vet clinics with a linked login account that can log
services. Distinct from the reimbursement providers in providers.py."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

import models, schemas, auth as auth_utils
from database import get_db

router = APIRouter(tags=["admin"])


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
