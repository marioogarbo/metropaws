"""Read-only business KPIs for the management dashboard.

Every figure here is derived from live data — nothing is stored or cached.
Money is returned as whole pesos throughout, even where it is stored in
centavos, so the dashboard never has to know which is which.
"""
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models, auth as auth_utils
from app.database import get_db

router = APIRouter(tags=["admin"])


@router.get("/analytics/founding-location")
def founding_location_analytics(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    from collections import defaultdict

    reservations = db.query(models.FoundingReservation).all()

    counts: dict = defaultdict(lambda: {"total": 0, "approved": 0, "pending": 0, "rejected": 0})
    for r in reservations:
        brgy = (r.barangay or "").strip() or "Unknown"
        status_key = r.status.value if hasattr(r.status, "value") else str(r.status)
        counts[brgy]["total"] += 1
        if status_key in counts[brgy]:
            counts[brgy][status_key] += 1

    return sorted(
        [{"barangay": k, **v} for k, v in counts.items()],
        key=lambda x: (-x["approved"], -x["total"]),
    )


@router.get("/analytics/overview")
def analytics_overview(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Business KPIs for the management dashboard: membership, revenue, plan
    mix, claims/payouts, and benefit utilization. All figures are derived
    read-only from live data. Revenue is whole pesos (payments); claim payouts
    are stored in centavos and returned as whole pesos."""

    total_members = db.query(func.count(models.Member.id)).scalar() or 0
    founding_members = (
        db.query(func.count(models.Member.id))
        .filter(models.Member.is_founding == True)  # noqa: E712
        .scalar()
        or 0
    )
    # An activated membership = a pet whose plan has been activated.
    active_memberships = (
        db.query(func.count(models.Pet.id))
        .filter(models.Pet.plan_activated_at.isnot(None))
        .scalar()
        or 0
    )

    plan_rows = (
        db.query(models.Pet.plan_type, func.count(models.Pet.id))
        .filter(models.Pet.plan_activated_at.isnot(None))
        .group_by(models.Pet.plan_type)
        .all()
    )
    plan_mix = [{"plan": plan or "Unknown", "count": count} for plan, count in plan_rows]

    revenue_php = (
        db.query(func.coalesce(func.sum(models.Payment.amount_php), 0))
        .filter(models.Payment.status == models.PaymentStatus.paid)
        .scalar()
        or 0
    )
    paid_payments = (
        db.query(func.count(models.Payment.id))
        .filter(models.Payment.status == models.PaymentStatus.paid)
        .scalar()
        or 0
    )

    claim_rows = (
        db.query(models.Reimbursement.status, func.count(models.Reimbursement.id))
        .group_by(models.Reimbursement.status)
        .all()
    )
    claims_by_status: dict = {}
    for status_value, count in claim_rows:
        key = status_value.value if hasattr(status_value, "value") else str(status_value)
        claims_by_status[key] = count
    total_claims = sum(claims_by_status.values())
    pending_review = (
        claims_by_status.get("pending", 0)
        + claims_by_status.get("under_review", 0)
        + claims_by_status.get("needs_info", 0)
    )

    payout_centavos = (
        db.query(func.coalesce(func.sum(models.Reimbursement.approved_amount_centavos), 0))
        .filter(models.Reimbursement.status == models.ReimbursementStatus.paid)
        .scalar()
        or 0
    )

    total_sessions = db.query(func.coalesce(func.sum(models.PetService.total_sessions), 0)).scalar() or 0
    used_sessions = db.query(func.coalesce(func.sum(models.PetService.used_sessions), 0)).scalar() or 0
    used_pct = round((used_sessions / total_sessions) * 100, 1) if total_sessions else 0.0

    partner_clinics = db.query(func.count(models.ClinicPartner.id)).scalar() or 0

    return {
        "members": {
            "total": total_members,
            "founding": founding_members,
            "active_memberships": active_memberships,
        },
        "revenue": {
            "total_php": int(revenue_php),
            "paid_payments": paid_payments,
        },
        "plan_mix": plan_mix,
        "claims": {
            "total": total_claims,
            "by_status": claims_by_status,
            "pending_review": pending_review,
            "payout_total_php": round(payout_centavos / 100),
        },
        "utilization": {
            "total_sessions": total_sessions,
            "used_sessions": used_sessions,
            "used_pct": used_pct,
        },
        "partner_clinics": partner_clinics,
    }


@router.get("/analytics/top-providers")
def top_providers_analytics(
    service_type_id: Optional[str] = Query(default=None),
    limit: Optional[int] = Query(default=None, ge=1, le=500),
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Where members spend out-of-pocket: reimbursement claims grouped by the
    provider name written on the claim (case/space-insensitive), ranked by claim
    count. Omitting ``limit`` returns every clinic, which feeds the dashboard's
    partnership-prospecting directory. Money is returned as whole pesos to match
    /analytics/overview."""
    from sqlalchemy import case

    norm = func.lower(func.trim(models.Reimbursement.provider_name))
    approved_states = (
        models.ReimbursementStatus.approved,
        models.ReimbursementStatus.paid,
    )
    approved_flag = case(
        (models.Reimbursement.status.in_(approved_states), 1),
        else_=0,
    )
    approved_amount = case(
        (
            models.Reimbursement.status.in_(approved_states),
            func.coalesce(models.Reimbursement.approved_amount_centavos, 0),
        ),
        else_=0,
    )

    q = db.query(
        func.max(models.Reimbursement.provider_name).label("provider"),
        func.count(models.Reimbursement.id).label("claims"),
        func.count(func.distinct(models.Reimbursement.member_id)).label("members"),
        func.coalesce(func.sum(approved_flag), 0).label("approved_claims"),
        func.coalesce(func.sum(models.Reimbursement.claimed_amount_centavos), 0).label("claimed_centavos"),
        func.coalesce(func.sum(approved_amount), 0).label("approved_centavos"),
        func.max(models.Reimbursement.service_date).label("last_visit"),
    )
    if service_type_id:
        q = q.filter(models.Reimbursement.service_type_id == service_type_id)

    q = q.group_by(norm).order_by(func.count(models.Reimbursement.id).desc())
    if limit is not None:
        q = q.limit(limit)
    rows = q.all()

    return [
        {
            "provider": r.provider,
            "claims": r.claims,
            "members": int(r.members),
            "approved_claims": int(r.approved_claims),
            "claimed_php": round(r.claimed_centavos / 100),
            "approved_php": round(r.approved_centavos / 100),
            "last_visit": r.last_visit.isoformat() if r.last_visit else None,
        }
        for r in rows
    ]
