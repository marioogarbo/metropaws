"""Admin edits to a member's pets."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

from app import models, schemas, auth as auth_utils
from app.database import get_db

router = APIRouter(tags=["admin"])


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
