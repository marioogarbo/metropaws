"""Outbound email for MetroPaws.

Two transports, picked automatically per send:

- **ZeptoMail HTTP API** — used when ``ZEPTOMAIL_TOKEN`` is set. Render's free
  tier blocks outbound SMTP ports (25/465/587), so production MUST send over
  HTTPS. The sender address (``EMAIL_FROM``/``SMTP_USER``) must belong to a
  domain verified in the ZeptoMail console.
- **Plain SMTP** — fallback for local dev when no ZeptoMail token is configured
  (``SMTP_HOST``/``SMTP_PORT``/``SMTP_USER``/``SMTP_PASSWORD``).
"""

import base64
import smtplib
from datetime import datetime, timedelta, timezone
from email.mime.application import MIMEApplication
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os

import httpx

# Fail fast instead of hanging the request when the SMTP host is unreachable
# (e.g. outbound port blocked on the hosting provider).
_SMTP_TIMEOUT = 25

_ZEPTOMAIL_URL_DEFAULT = "https://api.zeptomail.com/v1.1/email"


# ── Transport layer ───────────────────────────────────────────────────────────
def _send_via_zeptomail(
    to_email: str,
    subject: str,
    html_body: str,
    from_name: str,
    from_addr: str,
    attachments=None,
):
    """Send through ZeptoMail's transactional HTTP API. Raises on failure."""
    token = os.getenv("ZEPTOMAIL_TOKEN", "").strip()
    # The console shows the full header value; accept it with or without prefix.
    if not token.lower().startswith("zoho-enczapikey"):
        token = f"Zoho-enczapikey {token}"

    payload = {
        "from": {"address": from_addr, "name": from_name},
        "to": [{"email_address": {"address": to_email}}],
        "subject": subject,
        "htmlbody": html_body,
    }
    if attachments:
        payload["attachments"] = [
            {
                "content": base64.b64encode(content).decode("ascii"),
                "mime_type": mime_type,
                "name": filename,
            }
            for (filename, content, mime_type) in attachments
        ]

    url = os.getenv("ZEPTOMAIL_API_URL", _ZEPTOMAIL_URL_DEFAULT)
    resp = httpx.post(
        url,
        json=payload,
        headers={"Authorization": token, "Accept": "application/json"},
        timeout=30,
    )
    if resp.status_code >= 300:
        raise RuntimeError(
            f"ZeptoMail send failed (HTTP {resp.status_code}): {resp.text[:500]}"
        )


def _send_via_smtp(
    to_email: str,
    subject: str,
    html_body: str,
    from_name: str,
    from_addr: str,
    attachments=None,
):
    """Send through plain SMTP (local dev fallback). Raises on failure."""
    smtp_host = os.getenv("SMTP_HOST", "smtp.gmail.com")
    smtp_port = int(os.getenv("SMTP_PORT", 587))
    smtp_user = os.getenv("SMTP_USER")
    smtp_password = os.getenv("SMTP_PASSWORD")

    if not all([smtp_user, smtp_password]):
        raise ValueError("SMTP credentials not configured")

    if attachments:
        message = MIMEMultipart("mixed")
        alt = MIMEMultipart("alternative")
        alt.attach(MIMEText(html_body, "html"))
        message.attach(alt)
        for (filename, content, mime_type) in attachments:
            subtype = mime_type.split("/")[-1]
            part = MIMEApplication(content, _subtype=subtype)
            part.add_header("Content-Disposition", "attachment", filename=filename)
            message.attach(part)
    else:
        message = MIMEMultipart("alternative")
        message.attach(MIMEText(html_body, "html"))

    message["Subject"] = subject
    message["From"] = f"{from_name} <{from_addr}>"
    message["To"] = to_email

    with smtplib.SMTP(smtp_host, smtp_port, timeout=_SMTP_TIMEOUT) as server:
        server.starttls()
        server.login(smtp_user, smtp_password)
        server.send_message(message)


def _send_email(to_email: str, subject: str, html_body: str, from_name=None, attachments=None):
    """Send an HTML email via ZeptoMail when configured, else SMTP.

    ``attachments`` is a list of ``(filename, content_bytes, mime_type)``.
    Raises on any failure — callers decide whether to swallow.
    """
    from_name = from_name or os.getenv("EMAIL_FROM_NAME", "MetroPaws")
    from_addr = os.getenv("EMAIL_FROM") or os.getenv("SMTP_USER")
    if not from_addr:
        raise ValueError("No sender address configured (EMAIL_FROM or SMTP_USER)")

    if os.getenv("ZEPTOMAIL_TOKEN"):
        _send_via_zeptomail(to_email, subject, html_body, from_name, from_addr, attachments)
    else:
        _send_via_smtp(to_email, subject, html_body, from_name, from_addr, attachments)


# ── Password reset ────────────────────────────────────────────────────────────
def send_reset_email(to_email: str, reset_link: str, from_name: str = "MetroPaws"):
    subject = "Reset Your MetroPaws Password"

    html_body = f"""
    <!DOCTYPE html>
    <html>
      <body style="margin:0;padding:0;background:#f4f5f7;">
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;">
          Reset your MetroPaws password — this secure link expires in 1 hour.
        </div>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
               style="background:#f4f5f7;padding:32px 12px;">
          <tr><td align="center">
            <table role="presentation" width="600" cellpadding="0" cellspacing="0"
                   style="max-width:600px;width:100%;background:#ffffff;border-radius:16px;
                          overflow:hidden;box-shadow:0 1px 4px rgba(26,34,69,0.08);">
              <!-- Brand header -->
              <tr><td style="background:#263258;padding:26px 32px;text-align:center;">
                <img src="https://www.metropaws.ph/logo-full-white-metro.png"
                     alt="MetroPaws" height="36"
                     style="height:36px;display:inline-block;border:0;outline:none;">
              </td></tr>
              <!-- Body -->
              <tr><td style="padding:36px 32px 8px;font-family:Arial,Helvetica,sans-serif;color:#1a1e32;">
                <h1 style="margin:0 0 12px;font-size:22px;font-weight:bold;color:#263258;">
                  Reset your password
                </h1>
                <p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:#4a4f6a;">
                  Hi there, we received a request to reset your MetroPaws password.
                  Tap the button below to choose a new one.
                </p>
                <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 26px;">
                  <tr><td style="border-radius:12px;background:#263258;">
                    <a href="{reset_link}"
                       style="display:inline-block;padding:14px 34px;font-family:Arial,sans-serif;
                              font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none;
                              border-radius:12px;">
                      Reset Password
                    </a>
                  </td></tr>
                </table>
                <p style="margin:0 0 8px;font-size:13px;line-height:1.6;color:#8b8fa8;">
                  This link expires in <strong style="color:#4a4f6a;">1 hour</strong>. If you didn't
                  request a password reset, you can safely ignore this email — your password won't change.
                </p>
              </td></tr>
              <!-- Footer -->
              <tr><td style="padding:22px 32px 28px;border-top:1px solid #eef0f8;
                             font-family:Arial,Helvetica,sans-serif;">
                <p style="margin:0;font-size:12px;color:#a0a4bd;">
                  © 2026 MetroPaws Wellness Club Philippines, Inc.
                </p>
                <p style="margin:4px 0 0;font-size:12px;color:#a0a4bd;">
                  Need help? Reply to this email or contact csr@metropaws.ph
                </p>
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body>
    </html>
    """

    try:
        _send_email(to_email, subject, html_body, from_name=from_name)
    except Exception as e:
        raise Exception(f"Failed to send email: {str(e)}")


def _peso(centavos):
    if centavos is None:
        return None
    return f"₱{centavos / 100:,.2f}"


# ── Reimbursement claim status ───────────────────────────────────────────────
def send_claim_status_email(
    to_email: str,
    member_name: str,
    status: str,
    service_name: str,
    claimed_centavos: int,
    approved_centavos=None,
    admin_note=None,
    from_name: str = "MetroPaws",
    payout_target: str = "member",
    provider_name: str | None = None,
):
    """Notify a member that their reimbursement claim changed status.

    Sent on approved / rejected / needs_info / paid. Includes the admin's note so
    "receipt unclear, please resubmit" reaches the member's inbox. When
    payout_target is "provider", the copy reflects that MetroPaws is paying the
    named provider directly rather than reimbursing the member.
    """
    is_provider_target = payout_target == "provider" and provider_name

    headline = {
        "approved":   "Your payment request was approved" if is_provider_target else "Your reimbursement claim was approved",
        "paid":       f"We paid {provider_name}" if is_provider_target else "Your reimbursement has been released",
        "rejected":   "Update on your claim",
        "needs_info": "We need clearer info for your claim",
    }.get(status, "Update on your claim")

    if is_provider_target:
        intro = {
            "approved":   f"Good news, {member_name}! Your request to pay <b>{provider_name}</b> directly for <b>{service_name}</b> has been approved.",
            "paid":       f"Hi {member_name}, we've paid <b>{provider_name}</b> for your <b>{service_name}</b> — nothing more to pay at your appointment.",
            "rejected":   f"Hi {member_name}, your request to pay <b>{provider_name}</b> directly for <b>{service_name}</b> was not approved.",
            "needs_info": f"Hi {member_name}, we need clearer or more complete info before we can approve paying <b>{provider_name}</b> for your <b>{service_name}</b> appointment.",
        }.get(status, f"Hi {member_name}, there's an update on your <b>{service_name}</b> request.")
    else:
        intro = {
            "approved":   f"Good news, {member_name}! Your claim for <b>{service_name}</b> has been approved.",
            "paid":       f"Hi {member_name}, your reimbursement for <b>{service_name}</b> has been released.",
            "rejected":   f"Hi {member_name}, your claim for <b>{service_name}</b> was not approved.",
            "needs_info": f"Hi {member_name}, we need a clearer or more complete receipt for your <b>{service_name}</b> claim before we can continue.",
        }.get(status, f"Hi {member_name}, there's an update on your <b>{service_name}</b> claim.")

    rows = [("Service", service_name), ("Amount claimed", _peso(claimed_centavos))]
    if approved_centavos is not None and status in ("approved", "paid"):
        rows.append(("Amount approved", _peso(approved_centavos)))
    rows.append(("Status", status.replace("_", " ").title()))

    detail_rows = "".join(
        f'<tr><td style="padding:6px 12px;color:#666;">{label}</td>'
        f'<td style="padding:6px 12px;font-weight:600;">{value}</td></tr>'
        for label, value in rows if value is not None
    )

    note_block = ""
    if admin_note:
        note_block = (
            '<div style="margin:20px 0;padding:14px 16px;background:#fbf6e9;'
            'border-left:4px solid #b89a3e;border-radius:6px;">'
            f'<b>Note from MetroPaws:</b><br/>{admin_note}</div>'
        )

    resubmit_hint = ""
    if status == "needs_info":
        resubmit_hint = (
            '<p>Please open the MetroPaws app, go to your claim, and tap '
            '<b>Resubmit</b> to upload a clearer receipt.</p>'
        )

    html_body = f"""
    <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto;">
          <h2 style="color: #1a2245;">{headline}</h2>
          <p>{intro}</p>
          <table style="border-collapse:collapse;margin:16px 0;">{detail_rows}</table>
          {note_block}
          {resubmit_hint}
          <p style="color:#666;font-size:14px;">You can view this claim anytime in the MetroPaws app.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
          <p style="color: #999; font-size: 12px;">© 2026 MetroPaws Wellness Club Philippines, Inc.</p>
        </div>
      </body>
    </html>
    """

    _send_email(to_email, headline, html_body, from_name=from_name)


def _peso_php(amount_php) -> str:
    """Whole-peso amount with the ₱ glyph, for HTML email bodies (email clients
    render Unicode fine — unlike the bundled PDF font, hence the split)."""
    return f"₱{float(amount_php or 0):,.2f}"


# ── Payment receipt ──────────────────────────────────────────────────────────
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
