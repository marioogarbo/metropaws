from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from database import get_db
import models, schemas
import auth as auth_utils

router = APIRouter(prefix="/paw-points", tags=["paw-points"])


@router.get("/balance", response_model=schemas.PawPointsBalanceOut)
def get_balance(
    current_user: models.User = Depends(auth_utils.require_member),
    db: Session = Depends(get_db),
):
    member = current_user.member
    if not member:
        return schemas.PawPointsBalanceOut(current_balance=0, lifetime_earned=0)

    net = (
        db.query(func.sum(models.PawPointsTransaction.points))
        .filter(models.PawPointsTransaction.member_id == member.id)
        .scalar()
    ) or 0

    earned = (
        db.query(func.sum(models.PawPointsTransaction.points))
        .filter(
            models.PawPointsTransaction.member_id == member.id,
            models.PawPointsTransaction.points > 0,
        )
        .scalar()
    ) or 0

    return schemas.PawPointsBalanceOut(
        current_balance=max(0, net),
        lifetime_earned=earned,
    )


@router.get("/history", response_model=list[schemas.PawPointsTransactionOut])
def get_history(
    skip: int = 0,
    limit: int = 50,
    current_user: models.User = Depends(auth_utils.require_member),
    db: Session = Depends(get_db),
):
    member = current_user.member
    if not member:
        return []

    return (
        db.query(models.PawPointsTransaction)
        .filter(models.PawPointsTransaction.member_id == member.id)
        .order_by(models.PawPointsTransaction.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.get("/rewards", response_model=list[schemas.PawRewardOut])
def get_rewards(
    db: Session = Depends(get_db),
):
    return (
        db.query(models.PawPointsReward)
        .filter(models.PawPointsReward.is_active == True)
        .order_by(models.PawPointsReward.sort_order)
        .all()
    )
