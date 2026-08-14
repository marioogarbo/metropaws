"""Manual Paw Points awards. The member-facing side is routers/paw_points.py."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas, auth as auth_utils
from app.database import get_db
from app.domain.paw_points_utils import award_points

router = APIRouter(tags=["admin"])


@router.post("/paw-points/award", status_code=201)
def award_paw_points(
    payload: schemas.PawAwardRequest,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    member = db.query(models.Member).filter(models.Member.id == payload.member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    awarded = award_points(
        db,
        member_id=payload.member_id,
        activity_type="admin_manual_award",
        points_override=payload.points,
        notes=payload.notes,
    )
    db.commit()
    return {"member_id": payload.member_id, "points_awarded": awarded}
