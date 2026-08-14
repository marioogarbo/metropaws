"""How mail actually leaves the process.

Two transports, picked automatically per send:

- **ZeptoMail HTTP API** — used when ``ZEPTOMAIL_TOKEN`` is set. Render's free
  tier blocks outbound SMTP ports (25/465/587), so production MUST send over
  HTTPS. The sender address (``EMAIL_FROM``/``SMTP_USER``) must belong to a
  domain verified in the ZeptoMail console.
- **Plain SMTP** — fallback for local dev when no ZeptoMail token is configured
  (``SMTP_HOST``/``SMTP_PORT``/``SMTP_USER``/``SMTP_PASSWORD``).

Everything else in this package builds HTML and hands it to ``_send_email``.
"""
import base64
import smtplib
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import os

import httpx


# Fail fast instead of hanging the request when the SMTP host is unreachable
# (e.g. outbound port blocked on the hosting provider).
_SMTP_TIMEOUT = 25


_ZEPTOMAIL_URL_DEFAULT = "https://api.zeptomail.com/v1.1/email"


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
