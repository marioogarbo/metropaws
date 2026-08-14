"""Value formatting for the receipt.

The PDF prints the ISO code (``PHP 1,500.00``) rather than the ₱ glyph: the
bundled Montserrat weights do not include U+20B1 (verified), and a formal
document should never risk a missing-glyph box. Email bodies keep ₱.
"""
from datetime import datetime, timezone

import models


def _php(amount) -> str:
    """Format whole-peso amounts as 'PHP 1,500.00' (ISO code, glyph-safe)."""
    return f"PHP {float(amount or 0):,.2f}"


def _format_ph_phone(raw) -> str:
    """Normalise a PH mobile number to '+63 9XX XXX XXXX'.

    Accepts 9209224486 / 09209224486 / 639209224486 / +639209224486. Anything
    that isn't a recognisable 10-digit PH mobile is returned unchanged so we
    never mangle a landline or an already-formatted value."""
    if not raw:
        return ""
    s = str(raw).strip()
    digits = "".join(ch for ch in s if ch.isdigit())
    national = None
    if len(digits) == 12 and digits.startswith("63"):
        national = digits[2:]
    elif len(digits) == 11 and digits.startswith("0"):
        national = digits[1:]
    elif len(digits) == 10 and digits.startswith("9"):
        national = digits
    if national and len(national) == 10:
        return f"+63 {national[0:3]} {national[3:6]} {national[6:]}"
    return s


def invoice_number(payment: models.Payment) -> str:
    """Deterministic, stable receipt number: MP-<year>-<first 8 of id>.

    Derived from the payment id so a resend reproduces the SAME number rather
    than minting a new one. Not a sequential BIR OR series — see module docs."""
    when = payment.paid_at or payment.created_at or datetime.now(timezone.utc)
    short = (payment.id or "").replace("-", "")[:8].upper() or "00000000"
    return f"MP-{when.year}-{short}"


def _fmt_dt(dt: datetime | None) -> str:
    if not dt:
        return "—"
    # Show Manila wall-clock (payments store UTC).
    try:
        from datetime import timedelta
        local = dt.astimezone(timezone(timedelta(hours=8)))
    except Exception:
        local = dt
    return local.strftime("%d %b %Y, %I:%M %p")
