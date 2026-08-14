"""What the receipt says about the seller.

Env-configurable because the client is BIR-registered and these values change
independently of the code. Nothing is fabricated — TIN and permit lines render
only when their variable is set. See the INVOICE_* entries in CLAUDE.md.
"""
import config


def _biz() -> dict:
    """Read the seller identity from env at call time (never cached, so a
    redeploy with new values takes effect immediately). Only ``name`` has a
    default; every tax field is opt-in and skipped when blank."""
    return {
        "name": config.env("INVOICE_BUSINESS_NAME", "MetroPaws Wellness Club Philippines, Inc."),
        "address": config.env("INVOICE_BUSINESS_ADDRESS", "").strip(),
        "tin": config.env("INVOICE_BUSINESS_TIN", "").strip(),
        "email": (config.env("INVOICE_BUSINESS_EMAIL") or config.env("EMAIL_FROM") or config.env("SMTP_USER") or "").strip(),
        "phone": config.env("INVOICE_BUSINESS_PHONE", "").strip(),
        "website": config.env("INVOICE_BUSINESS_WEBSITE", "metropaws.ph").strip(),
        # BIR / registration lines printed in the footer when supplied.
        "reg_line": config.env("INVOICE_BUSINESS_REG_LINE", "").strip(),
        # Document heading. "PAYMENT RECEIPT" by default — set to "OFFICIAL
        # RECEIPT" ONLY once a BIR-accredited OR series is in place.
        "doc_title": config.env("INVOICE_DOC_TITLE", "PAYMENT RECEIPT").strip().upper(),
        # VAT breakdown. 0 (default) hides the tax lines entirely so we never
        # mis-state tax. Set e.g. "12" for a 12% VAT-inclusive breakdown.
        "vat_percent": float(config.env("INVOICE_VAT_PERCENT", "0") or 0),
    }
