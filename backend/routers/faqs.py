from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from database import get_db
import models, schemas, auth as auth_utils

public_router = APIRouter(tags=["faqs"])
admin_router = APIRouter(prefix="/admin", tags=["admin"])


@public_router.get("/faqs", response_model=List[schemas.FAQOut])
def list_faqs_public(db: Session = Depends(get_db)):
    return (
        db.query(models.FAQ)
        .filter(models.FAQ.is_published == True)
        .order_by(models.FAQ.sort_order)
        .all()
    )


@admin_router.get("/faqs", response_model=List[schemas.FAQOut])
def list_faqs_admin(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    return db.query(models.FAQ).order_by(models.FAQ.sort_order).all()


@admin_router.post("/faqs", response_model=schemas.FAQOut)
def create_faq(
    payload: schemas.FAQCreate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    faq = models.FAQ(**payload.model_dump())
    db.add(faq)
    db.commit()
    db.refresh(faq)
    return faq


@admin_router.put("/faqs/reorder")
def reorder_faqs(
    payload: schemas.FAQReorderRequest,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    for i, faq_id in enumerate(payload.ids):
        db.query(models.FAQ).filter(models.FAQ.id == faq_id).update({"sort_order": i})
    db.commit()
    return {"ok": True}


@admin_router.put("/faqs/{faq_id}", response_model=schemas.FAQOut)
def update_faq(
    faq_id: str,
    payload: schemas.FAQUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    faq = db.query(models.FAQ).filter(models.FAQ.id == faq_id).first()
    if not faq:
        raise HTTPException(status_code=404, detail="FAQ not found")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(faq, field, value)
    db.commit()
    db.refresh(faq)
    return faq


@admin_router.delete("/faqs/{faq_id}")
def delete_faq(
    faq_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    faq = db.query(models.FAQ).filter(models.FAQ.id == faq_id).first()
    if not faq:
        raise HTTPException(status_code=404, detail="FAQ not found")
    db.delete(faq)
    db.commit()
    return {"ok": True}
