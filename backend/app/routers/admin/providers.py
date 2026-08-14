"""Reimbursement providers — verified direct-pay payees."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas, auth as auth_utils
from app.database import get_db

router = APIRouter(tags=["admin"])


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
