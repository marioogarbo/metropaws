"""Admin review of reimbursement claims: approve against the right wallet,
request more information, reject, and release payment.

The member-facing side is routers/reimbursements.py. Approval holds a row lock
over the pet's claim set so two admins cannot overspend the same wallet.
"""
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload, selectinload

import config
import models, schemas, auth as auth_utils
import reimbursement_utils as rutils
from database import get_db

# When "true", the admin who approved a claim may NOT also mark it paid
# (segregation of duties). Off by default so single-admin setups still work.
_ENFORCE_DUAL_CONTROL = config.env_bool("REIMBURSEMENT_ENFORCE_DUAL_CONTROL", False)

router = APIRouter(tags=["admin"])


# --- Reimbursements (admin review) ---

def _reimbursement_query(db: Session):
    return db.query(models.Reimbursement).options(
        joinedload(models.Reimbursement.service_type),
        joinedload(models.Reimbursement.pet),
        joinedload(models.Reimbursement.member).joinedload(models.Member.user),
        joinedload(models.Reimbursement.provider),
        selectinload(models.Reimbursement.events),
    )


@router.get("/reimbursements", response_model=list[schemas.AdminReimbursementOut])
def list_reimbursements(
    status: Optional[str] = Query(None),
    member_id: Optional[str] = Query(None),
    skip: int = 0,
    limit: int = 100,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    # DPA access log: record admin access to members' financial data.
    print(f"[audit] admin={current_user.id} accessed reimbursements "
          f"(status={status}, member_id={member_id})")
    q = _reimbursement_query(db)
    if status:
        try:
            q = q.filter(models.Reimbursement.status == models.ReimbursementStatus(status))
        except ValueError as exc:
            raise HTTPException(status_code=400, detail="Invalid status value") from exc
    if member_id:
        q = q.filter(models.Reimbursement.member_id == member_id)
    return (
        q.order_by(models.Reimbursement.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.put("/reimbursements/{reimbursement_id}/review", response_model=schemas.AdminReimbursementOut)
def review_reimbursement(
    reimbursement_id: str,
    payload: schemas.ReimbursementReviewRequest,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    # Lock the claim row for the duration of the decision.
    claim = (
        db.query(models.Reimbursement)
        .filter(models.Reimbursement.id == reimbursement_id)
        .with_for_update()
        .first()
    )
    if not claim:
        raise HTTPException(status_code=404, detail="Claim not found")
    if claim.status == models.ReimbursementStatus.paid:
        raise HTTPException(status_code=400, detail="Paid claims can't be modified.")

    valid = {"under_review", "needs_info", "approved", "rejected"}
    if payload.status not in valid:
        raise HTTPException(status_code=422, detail=f"Status must be one of {sorted(valid)}")
    new_status = models.ReimbursementStatus(payload.status)

    note = (payload.admin_notes or "").strip()
    if new_status in (models.ReimbursementStatus.needs_info, models.ReimbursementStatus.rejected) and not note:
        raise HTTPException(
            status_code=422,
            detail="A note is required when requesting more info or rejecting a claim.",
        )

    if new_status == models.ReimbursementStatus.approved:
        if payload.approved_amount_centavos is None or payload.approved_amount_centavos <= 0:
            raise HTTPException(status_code=422, detail="approved_amount_centavos is required to approve.")
        pet = db.query(models.Pet).filter(models.Pet.id == claim.pet_id).first()
        # Approve against the pool this claim's category draws from.
        emergency = rutils.is_emergency_category(
            claim.service_type.name if claim.service_type else None
        )
        wallet = (
            rutils.plan_emergency_wallet_centavos(db, pet.plan_id if pet else None)
            if emergency
            else rutils.plan_wallet_centavos(db, pet.plan_id if pet else None)
        )
        # Lock the pet's claim set so two approvals can't overspend the wallet.
        prev_used, _prev_pending, emg_used, _emg_pending = rutils.wallet_usage(
            db, pet, exclude_id=claim.id, lock=True
        )
        used = emg_used if emergency else prev_used
        remaining = wallet - used
        if payload.approved_amount_centavos > remaining:
            wallet_name = "Emergency Wallet" if emergency else "Preventive Wellness Wallet"
            raise HTTPException(
                status_code=400,
                detail=f"Approved amount exceeds the remaining {wallet_name} (₱{max(0, remaining) // 100:,} left).",
            )
        claim.approved_amount_centavos = payload.approved_amount_centavos

    prev = claim.status
    claim.status = new_status
    if payload.admin_notes is not None:
        claim.admin_notes = payload.admin_notes
    claim.reviewed_by_admin_id = current_user.id
    claim.reviewed_at = datetime.now(timezone.utc)
    db.add(
        models.ReimbursementEvent(
            reimbursement_id=claim.id,
            from_status=prev.value,
            to_status=new_status.value,
            actor_user_id=current_user.id,
            note=note or None,
        )
    )
    db.commit()
    db.refresh(claim)

    if new_status in (
        models.ReimbursementStatus.approved,
        models.ReimbursementStatus.rejected,
        models.ReimbursementStatus.needs_info,
    ):
        rutils.notify_status(db, claim)

    return _reimbursement_query(db).filter(models.Reimbursement.id == claim.id).first()


@router.put("/reimbursements/{reimbursement_id}/mark-paid", response_model=schemas.AdminReimbursementOut)
def mark_reimbursement_paid(
    reimbursement_id: str,
    payload: schemas.MarkPaidRequest,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    reference = (payload.payment_reference or "").strip()
    if not reference:
        raise HTTPException(
            status_code=422,
            detail="A payment reference (GCash/bank transaction no.) is required to mark paid.",
        )

    claim = (
        db.query(models.Reimbursement)
        .filter(models.Reimbursement.id == reimbursement_id)
        .first()
    )
    if not claim:
        raise HTTPException(status_code=404, detail="Claim not found")
    if claim.status != models.ReimbursementStatus.approved:
        raise HTTPException(status_code=400, detail="Only approved claims can be marked paid.")

    # Segregation of duties: the approver can't also release payment (when enabled).
    if _ENFORCE_DUAL_CONTROL and claim.reviewed_by_admin_id == current_user.id:
        raise HTTPException(
            status_code=403,
            detail="A different admin must release payment (segregation of duties).",
        )

    prev = claim.status
    claim.status = models.ReimbursementStatus.paid
    claim.paid_by_admin_id = current_user.id
    claim.paid_at = datetime.now(timezone.utc)
    claim.paid_reference = reference
    if payload.admin_notes:
        claim.admin_notes = payload.admin_notes
    db.add(
        models.ReimbursementEvent(
            reimbursement_id=claim.id,
            from_status=prev.value,
            to_status=models.ReimbursementStatus.paid.value,
            actor_user_id=current_user.id,
            note=f"Reimbursement released (ref: {reference})",
        )
    )
    db.commit()
    db.refresh(claim)

    rutils.notify_status(db, claim)
    return _reimbursement_query(db).filter(models.Reimbursement.id == claim.id).first()
