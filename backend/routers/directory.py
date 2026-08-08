"""Public pet-care directory + its admin CRUD.

The public route is UNAUTHENTICATED. `DirectoryProvider` deliberately holds no
payout details (see the model docstring), so there is nothing here to leak — keep
it that way rather than adding a field and then filtering it out of the response.
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from database import get_db
import models, schemas, auth as auth_utils

public_router = APIRouter(tags=["directory"])
admin_router = APIRouter(prefix="/admin", tags=["admin"])


def _ordered(query):
    """Partners first, then alphabetical.

    Ordering is fixed server-side rather than admin-controlled: a directory is
    scanned, not read in sequence, so a manual sort_order would be upkeep for
    every new row with no benefit to the reader. `is_partner` is the only
    pin-to-top anyone has asked for.
    """
    return query.order_by(
        models.DirectoryProvider.is_partner.desc(),
        func.lower(models.DirectoryProvider.name),
    )


@public_router.get("/directory", response_model=List[schemas.DirectoryProviderOut])
def list_directory_public(db: Session = Depends(get_db)):
    return _ordered(
        db.query(models.DirectoryProvider).filter(
            models.DirectoryProvider.is_published == True
        )
    ).all()


@admin_router.get("/directory", response_model=List[schemas.DirectoryProviderOut])
def list_directory_admin(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    return _ordered(db.query(models.DirectoryProvider)).all()


@admin_router.post("/directory", response_model=schemas.DirectoryProviderOut)
def create_directory_provider(
    payload: schemas.DirectoryProviderCreate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    provider = models.DirectoryProvider(**payload.model_dump())
    db.add(provider)
    db.commit()
    db.refresh(provider)
    return provider


@admin_router.put("/directory/{provider_id}", response_model=schemas.DirectoryProviderOut)
def update_directory_provider(
    provider_id: str,
    payload: schemas.DirectoryProviderUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    provider = (
        db.query(models.DirectoryProvider)
        .filter(models.DirectoryProvider.id == provider_id)
        .first()
    )
    if not provider:
        raise HTTPException(status_code=404, detail="Directory listing not found")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(provider, field, value)
    db.commit()
    db.refresh(provider)
    return provider


@admin_router.delete("/directory/{provider_id}")
def delete_directory_provider(
    provider_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Hard delete — safe here because nothing references a directory listing.

    (Contrast reimbursement_providers, which must be deactivated instead because
    paid claims point at them.)
    """
    provider = (
        db.query(models.DirectoryProvider)
        .filter(models.DirectoryProvider.id == provider_id)
        .first()
    )
    if not provider:
        raise HTTPException(status_code=404, detail="Directory listing not found")
    db.delete(provider)
    db.commit()
    return {"ok": True}
