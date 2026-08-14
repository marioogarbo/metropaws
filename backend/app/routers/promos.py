from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app import models, schemas, auth as auth_utils

public_router = APIRouter(tags=["promos"])
admin_router = APIRouter(prefix="/admin", tags=["admin"])


@public_router.get("/promos", response_model=List[schemas.PromoOut])
def list_promos_public(db: Session = Depends(get_db)):
    return (
        db.query(models.Promo)
        .filter(models.Promo.is_published == True)  # noqa: E712
        .order_by(models.Promo.sort_order, models.Promo.created_at.desc())
        .all()
    )


@admin_router.get("/promos", response_model=List[schemas.PromoOut])
def list_promos_admin(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.Promo)
        .order_by(models.Promo.sort_order, models.Promo.created_at.desc())
        .all()
    )


@admin_router.post("/promos", response_model=schemas.PromoOut)
def create_promo(
    payload: schemas.PromoCreate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    promo = models.Promo(**payload.model_dump())
    db.add(promo)
    db.commit()
    db.refresh(promo)
    return promo


@admin_router.put("/promos/{promo_id}", response_model=schemas.PromoOut)
def update_promo(
    promo_id: str,
    payload: schemas.PromoUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    promo = db.query(models.Promo).filter(models.Promo.id == promo_id).first()
    if not promo:
        raise HTTPException(status_code=404, detail="Promo not found")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(promo, field, value)
    db.commit()
    db.refresh(promo)
    return promo


@admin_router.delete("/promos/{promo_id}")
def delete_promo(
    promo_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    promo = db.query(models.Promo).filter(models.Promo.id == promo_id).first()
    if not promo:
        raise HTTPException(status_code=404, detail="Promo not found")
    db.delete(promo)
    db.commit()
    return {"ok": True}
