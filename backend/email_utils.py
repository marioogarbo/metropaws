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
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from email.mime.application import MIMEApplication
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from html import escape
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


# ── Shared layout ─────────────────────────────────────────────────────────────
# Email clients can't read repo assets, so the logo is pulled from the marketing
# site's public folder over HTTPS.
_LOGO_WHITE_URL = "https://www.metropaws.ph/logo-full-white-metro.png"
_SUPPORT_EMAIL = "csr@metropaws.ph"


def _branded_shell(preheader: str, card_rows: str, footer_note: str = "") -> str:
    """Wrap ``card_rows`` in the MetroPaws email layout.

    ``card_rows`` is one or more ``<tr>`` blocks, placed as rows of the 600px
    card between the navy logo header and the footer. ``preheader`` is the hidden
    line inbox lists preview beside the subject; ``footer_note`` adds an optional
    closing line (e.g. why the recipient is getting this). Tables and inline
    styles throughout, because Outlook and Gmail strip stylesheets.
    """
    note_line = ""
    if footer_note:
        note_line = f"""
                <p style="margin:10px 0 0;font-size:12px;color:#a0a4bd;">
                  {footer_note}
                </p>"""

    return f"""
    <!DOCTYPE html>
    <html>
      <body style="margin:0;padding:0;background:#f4f5f7;">
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;">
          {preheader}
        </div>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
               style="background:#f4f5f7;padding:32px 12px;">
          <tr><td align="center">
            <table role="presentation" width="600" cellpadding="0" cellspacing="0"
                   style="max-width:600px;width:100%;background:#ffffff;border-radius:16px;
                          overflow:hidden;box-shadow:0 1px 4px rgba(26,34,69,0.08);">
              <!-- Brand header -->
              <tr><td style="background:#263258;padding:26px 32px;text-align:center;">
                <img src="{_LOGO_WHITE_URL}"
                     alt="MetroPaws" height="36"
                     style="height:36px;display:inline-block;border:0;outline:none;">
              </td></tr>
              {card_rows}
              <!-- Footer -->
              <tr><td style="padding:22px 32px 28px;border-top:1px solid #eef0f8;
                             font-family:Arial,Helvetica,sans-serif;">
                <p style="margin:0;font-size:12px;color:#a0a4bd;">
                  © 2026 MetroPaws Wellness Club Philippines, Inc.
                </p>
                <p style="margin:4px 0 0;font-size:12px;color:#a0a4bd;">
                  Need help? Reply to this email or contact {_SUPPORT_EMAIL}
                </p>{note_line}
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body>
    </html>
    """


# ── Password reset ────────────────────────────────────────────────────────────
def send_reset_email(to_email: str, reset_link: str, from_name: str = "MetroPaws"):
    subject = "Reset Your MetroPaws Password"

    html_body = _branded_shell(
        preheader="Reset your MetroPaws password — this secure link expires in 1 hour.",
        card_rows=f"""
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
              </td></tr>""",
    )

    try:
        _send_email(to_email, subject, html_body, from_name=from_name)
    except Exception as e:
        raise Exception(f"Failed to send email: {str(e)}") from e


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


# ── Android launch announcement ──────────────────────────────────────────────
# Mirrors website/lib/app-download.ts, which is the source of truth for install
# links. There is deliberately no App Store URL — iOS hasn't shipped yet.
PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.metropaws.mobile"

# Audience keys accepted by build_app_launch_email / send_app_launch_email.
AUDIENCE_FOUNDING_MEMBER = "founding_member"
AUDIENCE_FOUNDING_RESERVATION = "founding_reservation"
AUDIENCE_MEMBER = "member"


@dataclass(frozen=True)
class _LaunchCopy:
    """Per-audience wording for the launch announcement.

    Only these four strings change between audiences — the Play Store call to
    action, the feature list and the iOS section are identical for everyone.
    """

    subject: str
    intro: str
    aside: str = ""  # highlighted strip under the intro; blank = not rendered
    footer_note: str = ""


_ACCOUNT_FOOTER_NOTE = (
    "You're receiving this because you have a MetroPaws membership account."
)

_LAUNCH_COPY: dict[str, _LaunchCopy] = {
    AUDIENCE_FOUNDING_MEMBER: _LaunchCopy(
        subject="Founding Member: the MetroPaws app is live on Google Play",
        intro=(
            "You joined MetroPaws before there was an app to show for it — thank you "
            "for that trust. It's here now, and everything on your membership is in it."
        ),
        aside=(
            "Your <strong>Founding Member</strong> status is already on your account. "
            "Sign in with this same email address and you'll find it waiting."
        ),
        footer_note=_ACCOUNT_FOOTER_NOTE,
    ),
    AUDIENCE_MEMBER: _LaunchCopy(
        subject="The MetroPaws app is now live on Google Play",
        intro=(
            "Your membership now has a proper home on your phone. The MetroPaws app "
            "is live on Google Play, and your account is ready to sign in to."
        ),
        footer_note=_ACCOUNT_FOOTER_NOTE,
    ),
    AUDIENCE_FOUNDING_RESERVATION: _LaunchCopy(
        subject="The MetroPaws app is live — your Founding 50 slot is waiting",
        intro=(
            "You reserved one of our Founding 50 slots early on, and we've kept it — "
            "thank you. The MetroPaws app is now live on Google Play, and it's where "
            "you finish setting up your membership."
        ),
        aside=(
            "Your <strong>Founding 50 reservation</strong> is on file with our team. "
            "Create your account in the app using this same email address and we'll "
            "match it to your slot."
        ),
        footer_note=(
            "You're receiving this because you reserved a Founding 50 slot at metropaws.ph."
        ),
    ),
}

# Only features that actually ship in the Android build — nothing aspirational.
_LAUNCH_FEATURES = (
    (
        "Your digital membership ID",
        "A scannable QR code that pulls up you and your pets at the counter.",
    ),
    (
        "Every pet in one place",
        "Photos, breed, weight and vaccination cards, kept with the pet they belong to.",
    ),
    (
        "Benefits you can actually see",
        "What your plan covers, what's left in your Benefit Wallet, and the Paw Points you've earned.",
    ),
    (
        "Reimbursement claims from your phone",
        "Paid out of pocket? Send the receipt and follow the claim through to release.",
    ),
)


def build_app_launch_email(first_name: str, audience: str) -> tuple[str, str]:
    """Return ``(subject, html_body)`` for the Android launch announcement.

    ``audience`` is one of the ``AUDIENCE_*`` constants. Raises ``ValueError`` on
    anything else rather than guessing — the wrong variant would tell someone
    they're a Founding Member when they aren't.
    """
    if audience not in _LAUNCH_COPY:
        raise ValueError(
            f"Unknown audience {audience!r}; expected one of {sorted(_LAUNCH_COPY)}"
        )
    copy = _LAUNCH_COPY[audience]

    # Names come from an admin spreadsheet export, so escape before interpolating.
    greeting_name = escape((first_name or "").strip()) or "there"

    features_html = "".join(
        f"""
                  <tr>
                    <td width="26" valign="top"
                        style="padding:0 0 16px;font-size:15px;line-height:1.5;color:#b89a3e;">&#10003;</td>
                    <td valign="top"
                        style="padding:0 0 16px;font-size:14px;line-height:1.55;color:#4a4f6a;">
                      <strong style="color:#1a1e32;">{title}</strong><br>{detail}
                    </td>
                  </tr>"""
        for title, detail in _LAUNCH_FEATURES
    )

    aside_html = ""
    if copy.aside:
        aside_html = f"""
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                       style="margin:0 0 26px;background:#fbf6e9;border-radius:8px;">
                  <tr>
                    <td width="4" style="background:#b89a3e;font-size:0;line-height:0;">&nbsp;</td>
                    <td style="padding:14px 18px;font-size:14px;line-height:1.6;color:#4a4f6a;">
                      {copy.aside}
                    </td>
                  </tr>
                </table>"""

    card_rows = f"""
              <!-- Headline + intro -->
              <tr><td style="padding:34px 32px 0;font-family:Arial,Helvetica,sans-serif;">
                <p style="margin:0 0 10px;font-size:11px;font-weight:bold;letter-spacing:1.4px;
                          text-transform:uppercase;color:#b89a3e;">
                  Now on Google Play
                </p>
                <h1 style="margin:0 0 18px;font-size:26px;line-height:1.25;font-weight:bold;color:#263258;">
                  The MetroPaws app is here
                </h1>
                <p style="margin:0 0 16px;font-size:15px;line-height:1.65;color:#1a1e32;">
                  Hi {greeting_name},
                </p>
                <p style="margin:0 0 26px;font-size:15px;line-height:1.65;color:#4a4f6a;">
                  {copy.intro}
                </p>
                {aside_html}
                <!-- Primary call to action -->
                <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 8px;">
                  <tr><td style="border-radius:12px;background:#263258;">
                    <a href="{PLAY_STORE_URL}"
                       style="display:inline-block;padding:14px 34px;font-family:Arial,sans-serif;
                              font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none;
                              border-radius:12px;">
                      Get it on Google Play
                    </a>
                  </td></tr>
                </table>
                <p style="margin:0 0 30px;font-size:12px;line-height:1.5;color:#a0a4bd;">
                  Button not working? Search <strong style="color:#8b8fa8;">MetroPaws</strong>
                  on the Google Play Store.
                </p>
              </td></tr>
              <!-- What's inside -->
              <tr><td style="padding:0 32px;font-family:Arial,Helvetica,sans-serif;">
                <p style="margin:0 0 16px;font-size:12px;font-weight:bold;letter-spacing:1px;
                          text-transform:uppercase;color:#263258;">
                  What's waiting inside
                </p>
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0">{features_html}
                </table>
              </td></tr>
              <!-- iOS status -->
              <tr><td style="padding:10px 32px 0;font-family:Arial,Helvetica,sans-serif;">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                       style="background:#f7f8fb;border:1px solid #eef0f8;border-radius:12px;">
                  <tr><td style="padding:20px 22px;">
                    <p style="margin:0 0 8px;font-size:11px;font-weight:bold;letter-spacing:1.2px;
                              text-transform:uppercase;color:#b89a3e;">
                      iPhone &amp; iPad — in progress
                    </p>
                    <p style="margin:0 0 12px;font-size:15px;font-weight:bold;color:#263258;">
                      On iOS? We haven't forgotten you.
                    </p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#4a4f6a;">
                      MetroPaws is Android-only today, and we know that leaves some of you
                      waiting. We've already mapped out what the iOS version needs and that
                      work is underway — you're a big part of why it's next on our list.
                      When the App Store listing goes live, you'll hear it here first.
                      Nothing for you to do in the meantime.
                    </p>
                  </td></tr>
                </table>
              </td></tr>
              <!-- Sign-off -->
              <tr><td style="padding:26px 32px 30px;font-family:Arial,Helvetica,sans-serif;">
                <p style="margin:0 0 4px;font-size:15px;line-height:1.65;color:#4a4f6a;">
                  Maraming salamat sa tiwala — see you in the app.
                </p>
                <p style="margin:0;font-size:15px;font-weight:bold;color:#263258;">
                  The MetroPaws Team
                </p>
              </td></tr>"""

    html_body = _branded_shell(
        preheader=(
            "The MetroPaws app is now on Google Play — and here's where we are with iOS."
        ),
        card_rows=card_rows,
        footer_note=copy.footer_note,
    )
    return copy.subject, html_body


def send_app_launch_email(
    to_email: str,
    first_name: str,
    audience: str,
    from_name: str = None,
):
    """Send one member/reservation the Android launch announcement.

    Raises on failure so the broadcast script can log the address and keep going.
    """
    subject, html_body = build_app_launch_email(first_name, audience)
    _send_email(to_email, subject, html_body, from_name=from_name)
