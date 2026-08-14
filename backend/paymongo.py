"""PayMongo REST client — Checkout Sessions, webhook verification.

Uses the hosted Checkout Session API (the branded "Open in GCash" + dynamic-QR
page) rather than the deprecated Sources API. Checkout Sessions charge
automatically, so there is no manual source.chargeable -> create-payment step.

Docs: https://developers.paymongo.com/reference/checkout-session-resource
"""
import base64
import hashlib
import hmac
import httpx

import config

PAYMONGO_BASE = "https://api.paymongo.com/v1"


def _auth_headers() -> dict:
    key = config.env("PAYMONGO_SECRET_KEY")
    if not key:
        raise RuntimeError("PAYMONGO_SECRET_KEY is not set")
    encoded = base64.b64encode(f"{key}:".encode()).decode()
    return {
        "Authorization": f"Basic {encoded}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }


async def create_checkout_session(
    line_item_name: str,
    amount_centavos: int,
    success_url: str,
    cancel_url: str,
    reference_number: str,
    metadata: dict,
) -> dict:
    """Create a hosted Checkout Session and return its `data` object.

    Caller reads `data["id"]` (cs_...) and `data["attributes"]["checkout_url"]`.
    `success_url`/`cancel_url` MUST be http(s) URLs (PayMongo rejects custom
    schemes) — point them at the backend /payments/return/* pages, which then
    deep-link back into the app.
    """
    body = {
        "data": {
            "attributes": {
                "line_items": [
                    {
                        "name": line_item_name,
                        "amount": amount_centavos,
                        "currency": "PHP",
                        "quantity": 1,
                    }
                ],
                # PayMongo hides any method not ACTIVATED on the account, so
                # this list is the superset we're willing to offer — a code
                # entry alone does nothing until the method is enabled/approved
                # in the PayMongo dashboard (Settings -> Payment Methods).
                # QRPh is active from day one (scan-to-pay from GCash/Maya/any
                # PH bank app). "card" = Visa/Mastercard/JCB; it only shows once
                # card processing is approved on the live account. Add
                # "paymaya"/"grab_pay"/"dob" the same way when needed.
                "payment_method_types": [
                    "card",
                    "gcash",
                    "grab_pay",
                    "paymaya",
                    "qrph",
                ],
                "success_url": success_url,
                "cancel_url": cancel_url,
                "description": line_item_name,
                "reference_number": reference_number,
                "send_email_receipt": False,
                "metadata": metadata,
            }
        }
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
        r = await client.post(
            f"{PAYMONGO_BASE}/checkout_sessions", json=body, headers=_auth_headers()
        )
        r.raise_for_status()
        return r.json()["data"]


async def retrieve_checkout_session(session_id: str) -> dict:
    """Fetch a Checkout Session by id (cs_...) and return its `data` object.

    Used to reconcile payment status when the webhook hasn't arrived (e.g. the
    server was asleep when PayMongo called). The paid payment id, if any, is at
    data["attributes"]["payments"][n] where attributes.status == "paid".
    """
    async with httpx.AsyncClient(timeout=30.0) as client:
        r = await client.get(
            f"{PAYMONGO_BASE}/checkout_sessions/{session_id}",
            headers=_auth_headers(),
        )
        r.raise_for_status()
        return r.json()["data"]


def get_paid_payment_method(session_id: str) -> str | None:
    """Return the method actually used to pay a Checkout Session.

    Reads the paid payment under the session and returns its method code
    (e.g. 'qrph', 'gcash', 'card', 'grab_pay'), or None if it can't be
    determined. Best-effort and SYNCHRONOUS so receipt generation (also sync)
    can call it; any failure returns None so a receipt still renders.
    """
    key = config.env("PAYMONGO_SECRET_KEY")
    if not key or not session_id:
        return None
    try:
        with httpx.Client(timeout=10.0) as client:
            r = client.get(
                f"{PAYMONGO_BASE}/checkout_sessions/{session_id}",
                headers=_auth_headers(),
            )
            r.raise_for_status()
            data = r.json()["data"]
        for p in data.get("attributes", {}).get("payments") or []:
            attrs = p.get("attributes", {})
            if attrs.get("status") == "paid":
                source = attrs.get("source") or {}
                # `payment_method_used` is the canonical field; `source.type`
                # is the fallback (older payloads / e-wallets).
                return attrs.get("payment_method_used") or source.get("type")
    except Exception:
        return None
    return None


def verify_webhook_signature(payload: bytes, signature_header: str) -> bool:
    """PayMongo signature header: 't=<unix>,te=<test_sig>,li=<live_sig>'."""
    secret = config.env("PAYMONGO_WEBHOOK_SECRET")
    if not secret:
        raise RuntimeError("PAYMONGO_WEBHOOK_SECRET is not set")
    try:
        parts = dict(p.split("=", 1) for p in signature_header.split(","))
    except ValueError:
        return False
    timestamp = parts.get("t")
    sig = parts.get("li") or parts.get("te")
    if not timestamp or not sig:
        return False
    signed = f"{timestamp}.{payload.decode()}".encode()
    expected = hmac.new(secret.encode(), signed, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, sig)
