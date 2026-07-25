from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
import models, schemas

router = APIRouter(prefix="/plans", tags=["plans"])


@router.get("", response_model=list[schemas.PlanOut])
def list_plans(db: Session = Depends(get_db)):
    return (
        db.query(models.Plan)
        .filter(models.Plan.is_active == True)
        .order_by(models.Plan.sort_order)
        .all()
    )
