"""When the receipt is built and sent.

Two entry points with deliberately opposite failure behaviour:

- ``generate_and_send`` RAISES, so the admin "Resend invoice" endpoint can show
  the operator a real reason.
- ``notify_payment_receipt`` NEVER raises. It runs on the automatic path from
  ``_grant_plan``, where a mail hiccup must not fail a payment grant — a paid
  member with no plan is far worse than a missing receipt email.
"""
import logging

from sqlalchemy.orm import Session, joinedload

import email_utils
import models
from invoice_utils.render import render_invoice_pdf

logger = logging.getLogger("metropaws.invoice")


def _load_context(db: Session, payment: models.Payment):
    """Re-fetch the payment with member/user/plan/pet eagerly loaded so the PDF
    and email have everything even when called right after a commit."""
    return (
        db.query(models.Payment)
        .options(
            joinedload(models.Payment.member).joinedload(models.Member.user),
            joinedload(models.Payment.plan),
            joinedload(models.Payment.pet),
        )
        .filter(models.Payment.id == payment.id)
        .first()
    )


def build_receipt_pdf(db: Session, payment: models.Payment) -> tuple[bytes, str, str]:
    """Build the receipt PDF for a payment without sending anything.

    Used by the admin view/download endpoint. Returns (pdf_bytes, invoice_no,
    filename). Raises ValueError if the payment has no member."""
    p = _load_context(db, payment) or payment
    member = p.member
    if not member:
        raise ValueError("Payment has no member.")
    return render_invoice_pdf(p, member, p.plan, p.pet)


def generate_and_send(db: Session, payment: models.Payment) -> str:
    """Generate the receipt PDF and email it to the member.

    Raises on any failure (no member/email, PDF error, SMTP error) so the admin
    resend endpoint can report why. Returns the invoice number on success.
    """

    p = _load_context(db, payment) or payment
    member = p.member
    if not member:
        raise ValueError("Payment has no member.")
    if not member.email:
        raise ValueError("Member has no email address on file.")

    pdf_bytes, inv_no, filename = render_invoice_pdf(p, member, p.plan, p.pet)

    email_utils.send_payment_receipt_email(
        to_email=member.email,
        member_name=member.first_name or "there",
        plan_name=(p.plan.name if p.plan else "your plan"),
        pet_name=(p.pet.name if p.pet else None),
        amount_php=p.amount_php,
        invoice_no=inv_no,
        paid_at=p.paid_at or p.created_at,
        pdf_bytes=pdf_bytes,
        pdf_filename=filename,
    )
    return inv_no


def notify_payment_receipt(db: Session, payment: models.Payment) -> bool:
    """Best-effort receipt send used on the auto path (``_grant_plan``).

    Never raises — a mail failure must not roll back or block a plan grant.
    Returns True if the email was sent."""
    try:
        inv_no = generate_and_send(db, payment)
        logger.info("Emailed payment receipt %s for payment %s", inv_no, payment.id)
        return True
    except Exception:
        logger.exception("Failed to send payment receipt for payment %s", payment.id)
        return False
