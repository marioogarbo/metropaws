"""Admin PawPoints: per-member balances, the ledger, manual awards, and the
rewards catalogue. The member-facing side is routers/paw_points.py.

Balances are never stored. `paw_points_transactions` is an append-only ledger and
every figure here is a SUM over it, exactly as the member endpoint computes it —
so the number an admin quotes to a member is the number in the member's app, and
there is no second copy to drift.
"""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app import models, schemas, auth as auth_utils
from app.database import get_db
from app.domain.paw_points_utils import award_points

router = APIRouter(tags=["admin"])

TOP_EARNER_COUNT = 10

_POSITIVE_POINTS = case(
    (models.PawPointsTransaction.points > 0, models.PawPointsTransaction.points),
    else_=0,
)
_NEGATIVE_POINTS = case(
    (models.PawPointsTransaction.points < 0, -models.PawPointsTransaction.points),
    else_=0,
)


def _member_totals_subquery(db: Session):
    """Per-member balance, lifetime earned, and last activity, in one pass.

    A subquery rather than a per-member loop: the members list would otherwise
    fire three aggregates per row.
    """
    return (
        db.query(
            models.PawPointsTransaction.member_id.label("member_id"),
            func.coalesce(func.sum(models.PawPointsTransaction.points), 0).label("balance"),
            func.coalesce(func.sum(_POSITIVE_POINTS), 0).label("earned"),
            func.max(models.PawPointsTransaction.created_at).label("last_at"),
        )
        .group_by(models.PawPointsTransaction.member_id)
        .subquery()
    )


@router.get("/paw-points/summary", response_model=schemas.PawPointsAdminSummaryOut)
def paw_points_summary(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Programme-wide totals for the admin dashboard.

    ``total_redeemed`` reads 0 until redemption ships — nothing writes a negative
    ledger row yet. It is computed from the ledger rather than hardcoded so it
    starts reporting the moment the first redemption is recorded.
    """
    issued, redeemed, outstanding = (
        db.query(
            func.coalesce(func.sum(_POSITIVE_POINTS), 0),
            func.coalesce(func.sum(_NEGATIVE_POINTS), 0),
            func.coalesce(func.sum(models.PawPointsTransaction.points), 0),
        ).one()
    )

    totals = _member_totals_subquery(db)

    members_with_points = (
        db.query(func.count()).select_from(totals).filter(totals.c.balance > 0).scalar()
    ) or 0

    top_rows = (
        db.query(models.Member, totals.c.balance, totals.c.earned)
        .join(totals, totals.c.member_id == models.Member.id)
        .order_by(totals.c.earned.desc())
        .limit(TOP_EARNER_COUNT)
        .all()
    )
    top_earners = [
        schemas.PawPointsTopEarnerOut(
            member_id=member.id,
            first_name=member.first_name,
            last_name=member.last_name,
            lifetime_earned=int(earned or 0),
            current_balance=max(0, int(balance or 0)),
        )
        for member, balance, earned in top_rows
    ]

    rewards = (
        db.query(models.PawPointsReward)
        .filter(models.PawPointsReward.is_active == True)  # noqa: E712
        .order_by(models.PawPointsReward.sort_order)
        .all()
    )
    reward_reach = [
        schemas.PawRewardReachOut(
            reward_id=reward.id,
            name=reward.name,
            points_required=reward.points_required,
            members_eligible=(
                db.query(func.count())
                .select_from(totals)
                .filter(totals.c.balance >= reward.points_required)
                .scalar()
            )
            or 0,
        )
        for reward in rewards
    ]

    return schemas.PawPointsAdminSummaryOut(
        total_issued=int(issued or 0),
        total_redeemed=int(redeemed or 0),
        total_outstanding=max(0, int(outstanding or 0)),
        members_with_points=members_with_points,
        top_earners=top_earners,
        reward_reach=reward_reach,
    )


@router.get(
    "/paw-points/members",
    response_model=list[schemas.PawPointsMemberBalanceOut],
)
def list_member_balances(
    search: Optional[str] = None,
    skip: int = 0,
    limit: int = Query(default=50, le=200),
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Every member with their balance — the answer to "paw points per member".

    Members who have never earned a point are included, at zero, via an outer
    join. Excluding them would make an empty result ambiguous: it could mean
    "nobody earned anything" or "no such member".
    """
    totals = _member_totals_subquery(db)

    query = (
        db.query(
            models.Member,
            totals.c.balance,
            totals.c.earned,
            totals.c.last_at,
        )
        .outerjoin(totals, totals.c.member_id == models.Member.id)
        .join(models.User, models.User.id == models.Member.user_id)
    )

    if search:
        term = f"%{search.strip()}%"
        query = query.filter(
            models.Member.first_name.ilike(term)
            | models.Member.last_name.ilike(term)
            | models.User.email.ilike(term)
        )

    rows = (
        query.order_by(func.coalesce(totals.c.balance, 0).desc(), models.Member.last_name)
        .offset(skip)
        .limit(limit)
        .all()
    )

    return [
        schemas.PawPointsMemberBalanceOut(
            member_id=member.id,
            first_name=member.first_name,
            last_name=member.last_name,
            email=member.user.email if member.user else None,
            plan_type=member.plan_type,
            current_balance=max(0, int(balance or 0)),
            lifetime_earned=int(earned or 0),
            last_activity_at=last_at,
        )
        for member, balance, earned, last_at in rows
    ]


@router.get(
    "/paw-points/members/{member_id}",
    response_model=schemas.PawPointsMemberDetailOut,
)
def member_paw_points_detail(
    member_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """One member's balance and full ledger — what an admin reads out on a call."""
    if not db.query(models.Member).filter(models.Member.id == member_id).first():
        raise HTTPException(status_code=404, detail="Member not found")

    net, earned = (
        db.query(
            func.coalesce(func.sum(models.PawPointsTransaction.points), 0),
            func.coalesce(func.sum(_POSITIVE_POINTS), 0),
        )
        .filter(models.PawPointsTransaction.member_id == member_id)
        .one()
    )

    history = (
        db.query(models.PawPointsTransaction)
        .filter(models.PawPointsTransaction.member_id == member_id)
        .order_by(models.PawPointsTransaction.created_at.desc())
        .all()
    )

    return schemas.PawPointsMemberDetailOut(
        balance=schemas.PawPointsBalanceOut(
            current_balance=max(0, int(net or 0)),
            lifetime_earned=int(earned or 0),
        ),
        history=history,
    )


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


# ── Rewards catalogue ────────────────────────────────────────────────────────
# Until now the catalogue could only be changed by a developer running a seeder
# or pasting SQL, which is how production came to serve an empty rewards list.


@router.get("/paw-points/rewards", response_model=list[schemas.PawRewardOut])
def list_rewards_admin(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Includes inactive rewards, unlike the member endpoint — an admin has to be
    able to see what they retired in order to bring it back."""
    return (
        db.query(models.PawPointsReward)
        .order_by(models.PawPointsReward.sort_order)
        .all()
    )


@router.post("/paw-points/rewards", response_model=schemas.PawRewardOut, status_code=201)
def create_reward(
    payload: schemas.PawRewardCreate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    reward = models.PawPointsReward(**payload.model_dump())
    db.add(reward)
    db.commit()
    db.refresh(reward)
    return reward


@router.patch("/paw-points/rewards/{reward_id}", response_model=schemas.PawRewardOut)
def update_reward(
    reward_id: str,
    payload: schemas.PawRewardUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    reward = (
        db.query(models.PawPointsReward)
        .filter(models.PawPointsReward.id == reward_id)
        .first()
    )
    if not reward:
        raise HTTPException(status_code=404, detail="Reward not found")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(reward, field, value)

    db.commit()
    db.refresh(reward)
    return reward


@router.delete("/paw-points/rewards/{reward_id}", status_code=204)
def delete_reward(
    reward_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """For a mistyped entry. To retire a reward members have already seen, PATCH
    ``is_active=false`` instead — once redemptions are recorded, deleting the
    reward they point at would orphan that history.
    """
    reward = (
        db.query(models.PawPointsReward)
        .filter(models.PawPointsReward.id == reward_id)
        .first()
    )
    if not reward:
        raise HTTPException(status_code=404, detail="Reward not found")

    db.delete(reward)
    db.commit()
