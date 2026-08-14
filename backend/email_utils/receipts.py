"""Payment receipt email.

The PDF itself is built in invoice_utils; this is the covering message it is
attached to. Amounts here are whole pesos (Payment.amount_php), not centavos.
"""
from datetime import datetime, timedelta, timezone

from email_utils.transport import _send_email


def _peso_php(amount_php) -> str:
    """Whole-peso amount with the ₱ glyph, for HTML email bodies (email clients
    render Unicode fine — unlike the bundled PDF font, hence the split)."""
    return f"₱{float(amount_php or 0):,.2f}"


def send_payment_receipt_email(
    to_email: str,
    member_name: str,
    plan_name: str,
    amount_php,
    invoice_no: str,
    paid_at: datetime | None,
    pdf_bytes: bytes,
    pdf_filename: str,
    pet_name: str | None = None,
    from_name: str = None,
):
    """Email a member their branded PDF payment receipt after a plan payment.

    The PDF is attached; the HTML body is a short confirmation. Raises on
    failure so the caller (admin resend) can report it; the auto path wraps this
    in ``invoice_utils.notify_payment_receipt`` which swallows exceptions.
    """
    subject = f"Your MetroPaws payment receipt · {invoice_no}"
    paid_when = ""
    if paid_at:
        try:
            local = paid_at.astimezone(timezone(timedelta(hours=8)))
        except Exception:
            local = paid_at
        paid_when = local.strftime("%d %b %Y, %I:%M %p")

    for_pet = f" for <b>{pet_name}</b>" if pet_name else ""
    rows = [
        ("Plan", plan_name),
        ("Amount paid", _peso_php(amount_php)),
        ("Receipt no.", invoice_no),
    ]
    if paid_when:
        rows.append(("Paid on", paid_when))
    detail_rows = "".join(
        f'<tr><td style="padding:6px 12px;color:#666;">{label}</td>'
        f'<td style="padding:6px 12px;font-weight:600;">{value}</td></tr>'
        for label, value in rows
    )

    html_body = f"""
    <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto;">
          <h2 style="color: #1a2245;">Payment received — thank you!</h2>
          <p>Hi {member_name}, we've received your payment{for_pet}. Your membership is now active.</p>
          <p>Your official receipt is attached to this email as a PDF.</p>
          <table style="border-collapse:collapse;margin:16px 0;">{detail_rows}</table>
          <p style="color:#666;font-size:14px;">You can view your membership anytime in the MetroPaws app.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
          <p style="color: #999; font-size: 12px;">© 2026 MetroPaws Wellness Club Philippines, Inc.</p>
        </div>
      </body>
    </html>
    """

    _send_email(
        to_email,
        subject,
        html_body,
        from_name=from_name,
        attachments=[(pdf_filename, pdf_bytes, "application/pdf")],
    )
