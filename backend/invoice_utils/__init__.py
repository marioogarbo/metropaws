"""Payment receipt generation for plan subscriptions.

This package replaced a 529-line invoice_utils.py; the name is unchanged, so
`import invoice_utils` and `invoice_utils.build_receipt_pdf` work as before.

    business    what the receipt says about the seller (env-configurable)
    formatting  peso amounts, phone numbers, dates, receipt numbers
    render      page geometry, palette, and drawing every section
    delivery    building and sending, and which path may raise

Currency note: ``Payment.amount_php`` is whole pesos — the reimbursement side
uses centavos. Do not mix them.
"""
from invoice_utils.delivery import (
    build_receipt_pdf,
    generate_and_send,
    notify_payment_receipt,
)
from invoice_utils.formatting import invoice_number
from invoice_utils.render import render_invoice_pdf

__all__ = [
    "build_receipt_pdf",
    "generate_and_send",
    "invoice_number",
    "notify_payment_receipt",
    "render_invoice_pdf",
]
