"""Outbound email for MetroPaws.

This package replaced a single 629-line email_utils.py. It keeps that name —
calling it `email` would shadow the standard library module the transport
imports MIMEText from.

    transport   how mail leaves the process (ZeptoMail HTTP API, or SMTP locally)
    layout      the shared branded shell every template should be built on
    password_reset / claims / receipts / app_launch    one template each

Every public name is re-exported here, so `import email_utils` and
`email_utils.send_claim_status_email` work exactly as before.
"""
from app.email_utils.app_launch import (
    AUDIENCE_FOUNDING_MEMBER,
    AUDIENCE_FOUNDING_RESERVATION,
    AUDIENCE_MEMBER,
    PLAY_STORE_URL,
    build_app_launch_email,
    send_app_launch_email,
)
from app.email_utils.claims import send_claim_status_email
from app.email_utils.password_reset import send_reset_email
from app.email_utils.receipts import send_payment_receipt_email

__all__ = [
    "AUDIENCE_FOUNDING_MEMBER",
    "AUDIENCE_FOUNDING_RESERVATION",
    "AUDIENCE_MEMBER",
    "PLAY_STORE_URL",
    "build_app_launch_email",
    "send_app_launch_email",
    "send_claim_status_email",
    "send_payment_receipt_email",
    "send_reset_email",
]
