"""Payment records and their PDF receipts — the drill-down behind the
dashboard's revenue figure, plus view/resend for a paid payment's receipt."""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy.orm import Session, joinedload

import models, schemas, auth as auth_utils
import invoice_utils
from database import get_db

logger = logging.getLogger(__name__)

router = APIRouter(tags=["admin"])


@router.get("/payments", response_model=list[schemas.AdminPaymentOut])
def list_payments(
    status: Optional[models.PaymentStatus] = Query(default=None),
    limit: int = Query(default=200, ge=1, le=1000),
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Every payment attempt with who made it — the drill-down behind the
    dashboard's Revenue Collected figure, so admins can reconcile against the
    PayMongo dashboard without leaving the app."""
    query = (
        db.query(models.Payment)
        .options(
            joinedload(models.Payment.member).joinedload(models.Member.user),
            joinedload(models.Payment.plan),
            joinedload(models.Payment.pet),
        )
        .order_by(models.Payment.created_at.desc())
    )
    if status is not None:
        query = query.filter(models.Payment.status == status)
    payments = query.limit(limit).all()

    return [
        schemas.AdminPaymentOut(
            id=p.id,
            member_id=p.member_id,
            member_first_name=p.member.first_name if p.member else "",
            member_last_name=p.member.last_name if p.member else "",
            member_email=p.member.email if p.member else None,
            pet_name=p.pet.name if p.pet else None,
            plan_name=p.plan.name if p.plan else None,
            amount_php=p.amount_php,
            currency=p.currency,
            status=p.status.value,
            provider=p.provider,
            provider_payment_id=p.provider_payment_id,
            created_at=p.created_at,
            paid_at=p.paid_at,
        )
        for p in payments
    ]


@router.get("/payments/{payment_id}/invoice")
def get_payment_invoice(
    payment_id: str,
    download: bool = Query(default=False),
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Return the branded PDF receipt for a paid payment so an admin can view or
    download it. ``?download=true`` forces a save dialog; otherwise it opens
    inline in the browser's PDF viewer (which itself offers a download)."""
    payment = (
        db.query(models.Payment)
        .filter(models.Payment.id == payment_id)
        .first()
    )
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if payment.status != models.PaymentStatus.paid:
        raise HTTPException(
            status_code=400,
            detail="Only paid payments have a receipt.",
        )

    try:
        pdf_bytes, _inv_no, filename = invoice_utils.build_receipt_pdf(db, payment)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception:
        raise HTTPException(status_code=500, detail="Could not generate the receipt PDF.")

    disposition = "attachment" if download else "inline"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'{disposition}; filename="{filename}"'},
    )


@router.post("/payments/{payment_id}/resend-invoice")
def resend_payment_invoice(
    payment_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    """Regenerate and re-email a paid payment's PDF receipt to the member.

    The same receipt is emailed automatically when a payment is confirmed; this
    lets an admin resend it (member deleted the email, wrong inbox, etc.). Only
    paid payments have a receipt. Unlike the auto path, failures surface to the
    operator so a misconfigured SMTP / missing email is visible."""
    payment = (
        db.query(models.Payment)
        .filter(models.Payment.id == payment_id)
        .first()
    )
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if payment.status != models.PaymentStatus.paid:
        raise HTTPException(
            status_code=400,
            detail="Only paid payments have a receipt to send.",
        )

    try:
        invoice_no = invoice_utils.generate_and_send(db, payment)
    except ValueError as e:
        # Expected, actionable problems (no member email, etc.).
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.exception("Resend receipt failed for payment %s", payment_id)
        raise HTTPException(
            status_code=502,
            detail=f"Could not send the receipt email ({type(e).__name__}: {e}). "
                   "Check the mail (SMTP) configuration and try again.",
        )

    return {
        "sent": True,
        "invoice_no": invoice_no,
        "email": payment.member.email if payment.member else None,
    }
