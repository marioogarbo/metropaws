"""Drawing the receipt: page geometry, palette, and every section of it.

``render_invoice_pdf`` is the only entry point; everything else draws one band
of the page. The palette is deliberately neutral — the logo carries the brand,
the type stays near-black on white with muted-grey labels and hairline rules.
"""
import logging
import os

import config
import models
from invoice_utils.business import _biz
from invoice_utils.formatting import _fmt_dt, _format_ph_phone, _php, invoice_number

# Same name as delivery's, so this is the same logger object the module always
# used — splitting the file must not change where these lines end up.
logger = logging.getLogger("metropaws.invoice")


# Neutral, high-contrast palette for a formal financial document. The logo
# carries the brand; the type stays near-black on white with muted-grey labels
# and hairline rules — no filled colour bands (reads calmer / more professional).
_INK = (24, 24, 27)          # near-black — headings, amounts, emphasis


_BODY = (39, 39, 42)         # body text


_MUTED = (106, 106, 114)     # labels, secondary text


_FAINT = (150, 150, 158)     # very light secondary


_LINE = (223, 223, 228)      # hairline borders / dividers


_RULE = (24, 24, 27)         # strong near-black rule (header / total)


_SURFACE = (248, 248, 247)   # barely-there row tint (used sparingly)


_WHITE = (255, 255, 255)


_PAID_GREEN = (21, 111, 64)      # accessible green for the PAID status


_PAID_GREEN_BG = (224, 240, 231)


# Anchored on the backend directory, not on __file__: this module moved into a
# package once already, and a relative-to-here path silently looked for the
# fonts inside invoice_utils/ and failed every render.
_ASSETS_DIR = str(config.BACKEND_DIR / "assets")


_LOGO_PATH = os.path.join(_ASSETS_DIR, "metropaws-logo.png")


_FONTS_DIR = os.path.join(_ASSETS_DIR, "fonts")


_PAGE_W = 210.0          # A4 width (mm)


_MARGIN = 16.0


_CONTENT_W = _PAGE_W - 2 * _MARGIN


def _new_pdf():
    from fpdf import FPDF

    pdf = FPDF(orientation="P", unit="mm", format="A4")
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.set_margins(_MARGIN, _MARGIN, _MARGIN)
    pdf.add_page()
    # Register brand font weights we actually use (unused styles would warn).
    pdf.add_font("Montserrat", "", os.path.join(_FONTS_DIR, "Montserrat-Regular.ttf"))
    pdf.add_font("Montserrat", "B", os.path.join(_FONTS_DIR, "Montserrat-Bold.ttf"))
    pdf.add_font("MontserratSemi", "", os.path.join(_FONTS_DIR, "Montserrat-SemiBold.ttf"))
    pdf.add_font("MontserratX", "", os.path.join(_FONTS_DIR, "Montserrat-ExtraBold.ttf"))
    return pdf


def _header(pdf, biz: dict) -> None:
    top = _MARGIN
    # Logo (aspect preserved from width). Skip gracefully if the asset is gone.
    if os.path.exists(_LOGO_PATH):
        try:
            pdf.image(_LOGO_PATH, x=_MARGIN, y=top + 1, w=42)
        except Exception:
            logger.warning("Invoice logo failed to render", exc_info=True)

    # Seller identity, right-aligned.
    right_w = 90.0
    right_x = _PAGE_W - _MARGIN - right_w
    pdf.set_xy(right_x, top)
    pdf.set_font("MontserratSemi", "", 10.5)
    pdf.set_text_color(*_INK)
    pdf.multi_cell(right_w, 5.0, biz["name"], align="R")

    pdf.set_font("Montserrat", "", 8.2)
    pdf.set_text_color(*_MUTED)
    lines = []
    if biz["address"]:
        # '|' breaks the address into deliberate lines (street / city + ZIP).
        for part in biz["address"].split("|"):
            part = part.strip()
            if part:
                lines.append(part)
    if biz["tin"]:
        lines.append(f"TIN: {biz['tin']}")
    if biz["email"]:
        lines.append(biz["email"])
    phone = _format_ph_phone(biz["phone"])
    if phone:
        lines.append(phone)
    if biz["website"]:
        lines.append(biz["website"])
    if lines:
        pdf.set_x(right_x)
        pdf.multi_cell(right_w, 4.3, "\n".join(lines), align="R")

    # Hairline rule under the header.
    y = max(pdf.get_y(), top + 24) + 4
    pdf.set_draw_color(*_LINE)
    pdf.set_line_width(0.3)
    pdf.line(_MARGIN, y, _PAGE_W - _MARGIN, y)
    pdf.set_y(y + 7)


def _title_block(pdf, biz: dict, inv_no: str, payment: models.Payment) -> None:
    y = pdf.get_y()
    # Document title (left).
    pdf.set_xy(_MARGIN, y)
    pdf.set_font("MontserratX", "", 19)
    pdf.set_text_color(*_INK)
    pdf.cell(110, 9, biz["doc_title"], align="L")

    # Meta (right): receipt no + issue date.
    meta_w = 74.0
    meta_x = _PAGE_W - _MARGIN - meta_w
    issued = payment.paid_at or payment.created_at

    def meta_row(label, value, dy):
        pdf.set_xy(meta_x, y + dy)
        pdf.set_font("Montserrat", "", 8)
        pdf.set_text_color(*_MUTED)
        pdf.cell(meta_w * 0.42, 4.6, label, align="L")
        pdf.set_font("MontserratSemi", "", 9)
        pdf.set_text_color(*_INK)
        pdf.cell(meta_w * 0.58, 4.6, value, align="R")

    meta_row("Receipt No.", inv_no, 0.5)
    meta_row("Date Issued", _fmt_dt(issued).split(",")[0], 5.6)
    pdf.set_y(y + 14)


def _parties_block(pdf, member: models.Member, payment: models.Payment) -> None:
    y = pdf.get_y() + 2
    col_w = (_CONTENT_W - 8) / 2

    # Billed-to block.
    _label(pdf, _MARGIN, y, "BILLED TO")
    name = f"{member.first_name} {member.last_name}".strip() or "MetroPaws Member"
    pdf.set_xy(_MARGIN, y + 5)
    pdf.set_font("MontserratSemi", "", 10.5)
    pdf.set_text_color(*_INK)
    pdf.cell(col_w, 5.4, name)
    detail = []
    if member.email:
        detail.append(member.email)
    phone = _format_ph_phone(getattr(member, "phone", None))
    if phone:
        detail.append(phone)
    if detail:
        pdf.set_xy(_MARGIN, y + 11)
        pdf.set_font("Montserrat", "", 8.6)
        pdf.set_text_color(*_MUTED)
        pdf.multi_cell(col_w, 4.4, "\n".join(detail))

    # Payment-status block (right).
    rx = _MARGIN + col_w + 8
    _label(pdf, rx, y, "PAYMENT")
    # PAID chip.
    chip_y = y + 4.5
    pdf.set_fill_color(*_PAID_GREEN_BG)
    pdf.set_xy(rx, chip_y)
    pdf.set_font("MontserratSemi", "", 8)
    pdf.set_text_color(*_PAID_GREEN)
    status_txt = (payment.status.value if hasattr(payment.status, "value") else str(payment.status)).upper()
    pdf.cell(24, 5.6, status_txt, border=0, align="C", fill=True, new_x="LMARGIN")

    rows = [
        ("Method", _method_label(payment)),
        ("Reference", payment.provider_payment_id or payment.provider_source_id or "—"),
        ("Paid on", _fmt_dt(payment.paid_at)),
    ]
    ry = chip_y + 8
    for label, value in rows:
        pdf.set_xy(rx, ry)
        pdf.set_font("Montserrat", "", 8)
        pdf.set_text_color(*_MUTED)
        pdf.cell(22, 4.6, label)
        pdf.set_font("MontserratSemi", "", 8)
        pdf.set_text_color(*_BODY)
        pdf.set_xy(rx + 22, ry)
        pdf.multi_cell(col_w - 22, 4.6, str(value))
        ry = max(pdf.get_y(), ry + 4.6) + 0.6

    pdf.set_y(max(y + 24, ry) + 5)


def _label(pdf, x, y, text) -> None:
    pdf.set_xy(x, y)
    pdf.set_font("MontserratSemi", "", 7.3)
    pdf.set_text_color(*_MUTED)
    pdf.cell(80, 4, text)


# Customer-facing labels for PayMongo method codes (the gateway name is
# deliberately omitted — the reference number already ties it to PayMongo).
_METHOD_LABELS = {
    "qrph": "QR Ph",
    "gcash": "GCash",
    "grab_pay": "GrabPay",
    "card": "Card",
    "paymaya": "Maya",
    "maya": "Maya",
    "dob": "Online Banking",
    "dob_ubp": "UnionBank Online",
    "billease": "BillEase",
}


def _method_label(payment: models.Payment) -> str:
    """The single method the member actually paid with.

    Fetches it from PayMongo (which records the chosen method); falls back to a
    neutral label if the provider isn't PayMongo or the lookup fails — never
    guesses a specific wallet."""
    code = None
    if (payment.provider or "").lower() == "paymongo" and payment.provider_source_id:
        try:
            import paymongo
            code = paymongo.get_paid_payment_method(payment.provider_source_id)
        except Exception:
            code = None
    if code:
        return _METHOD_LABELS.get(code.lower(), code.replace("_", " ").title())
    return "Online payment"


def _line_items(pdf, plan: models.Plan, pet, payment: models.Payment) -> None:
    # The plan line shows the FULL price; any Pack Discount is broken out in
    # the totals block so the math on the document reconstructs itself.
    discount = getattr(payment, "discount_php", 0) or 0
    amount_php = (payment.amount_php or 0) + discount
    desc_w = _CONTENT_W * 0.62
    qty_w = _CONTENT_W * 0.12
    amt_w = _CONTENT_W * 0.26

    # Column headings framed by a strong top rule + hairline below (no fill).
    y = pdf.get_y()
    pdf.set_draw_color(*_RULE)
    pdf.set_line_width(0.5)
    pdf.line(_MARGIN, y, _PAGE_W - _MARGIN, y)

    hy = y + 2.6
    pdf.set_xy(_MARGIN, hy)
    pdf.set_font("MontserratSemi", "", 7.6)
    pdf.set_text_color(*_MUTED)
    pdf.cell(desc_w, 5, "DESCRIPTION")
    pdf.cell(qty_w, 5, "QTY", align="C")
    pdf.cell(amt_w, 5, "AMOUNT", align="R")
    hy2 = hy + 6.4
    pdf.set_draw_color(*_LINE)
    pdf.set_line_width(0.3)
    pdf.line(_MARGIN, hy2, _PAGE_W - _MARGIN, hy2)

    # Single line item: the plan.
    plan_name = f"MetroPaws {plan.name} Plan" if plan else "MetroPaws Membership Plan"
    sub = "Annual membership"
    if pet is not None and getattr(pet, "name", None):
        sub += f" · for {pet.name}"

    row_y = hy2 + 3.4
    pdf.set_xy(_MARGIN, row_y)
    pdf.set_font("MontserratSemi", "", 9.8)
    pdf.set_text_color(*_INK)
    pdf.cell(desc_w, 5, plan_name)
    pdf.set_xy(_MARGIN + desc_w, row_y)
    pdf.set_font("Montserrat", "", 9.8)
    pdf.set_text_color(*_BODY)
    pdf.cell(qty_w, 5, "1", align="C")
    pdf.set_xy(_MARGIN + desc_w + qty_w, row_y)
    pdf.cell(amt_w, 5, _php(amount_php), align="R")

    pdf.set_xy(_MARGIN, row_y + 5.2)
    pdf.set_font("Montserrat", "", 8)
    pdf.set_text_color(*_MUTED)
    pdf.cell(desc_w, 4.4, sub)

    row_end = row_y + 5.2 + 5.2
    pdf.set_draw_color(*_LINE)
    pdf.set_line_width(0.3)
    pdf.line(_MARGIN, row_end, _PAGE_W - _MARGIN, row_end)
    pdf.set_y(row_end + 4)


def _totals(pdf, biz: dict, payment: models.Payment) -> None:
    total = float(payment.amount_php or 0)
    discount = float(getattr(payment, "discount_php", 0) or 0)
    block_w = 74.0
    x = _PAGE_W - _MARGIN - block_w

    def row(label, value):
        pdf.set_x(x)
        pdf.set_font("Montserrat", "", 8.8)
        pdf.set_text_color(*_MUTED)
        pdf.cell(block_w * 0.5, 6, label)
        pdf.set_font("MontserratSemi", "", 8.8)
        pdf.set_text_color(*_BODY)
        pdf.cell(block_w * 0.5, 6, value, align="R", new_x="LMARGIN", new_y="NEXT")

    if discount > 0:
        # Reconstructable math: Subtotal - Pack Discount = Total Paid. VAT
        # (below) stays computed on the actual consideration paid.
        row("Subtotal", _php(total + discount))
        row("Pack Discount", f"-{_php(discount)}")

    vat_pct = biz["vat_percent"]
    if vat_pct and vat_pct > 0:
        # Price is treated as VAT-inclusive (standard for PH consumer pricing).
        net = total / (1 + vat_pct / 100)
        vat = total - net
        row("VATable Sales", _php(net))
        row(f"VAT ({vat_pct:g}%)", _php(vat))

    # Grand total — a strong near-black rule above, bold figures, no fill.
    rule_y = pdf.get_y() + 1.5
    pdf.set_draw_color(*_RULE)
    pdf.set_line_width(0.5)
    pdf.line(x, rule_y, x + block_w, rule_y)

    pdf.set_xy(x, rule_y + 2.8)
    pdf.set_font("MontserratSemi", "", 9.2)
    pdf.set_text_color(*_INK)
    pdf.cell(block_w * 0.46, 7, "TOTAL PAID")
    pdf.set_font("MontserratX", "", 12.5)
    pdf.set_text_color(*_INK)
    pdf.set_xy(x + block_w * 0.46, rule_y + 2.4)
    pdf.cell(block_w * 0.54, 7.4, _php(total), align="R")
    pdf.set_y(rule_y + 13)


def _footer_note(pdf, biz: dict) -> None:
    y = pdf.get_y() + 3
    pdf.set_draw_color(*_LINE)
    pdf.set_line_width(0.3)
    pdf.line(_MARGIN, y, _PAGE_W - _MARGIN, y)
    pdf.set_xy(_MARGIN, y + 4.5)
    pdf.set_font("MontserratSemi", "", 9)
    pdf.set_text_color(*_INK)
    pdf.cell(_CONTENT_W, 5, "Thank you for being part of MetroPaws.")

    pdf.set_xy(_MARGIN, y + 10.5)
    pdf.set_font("Montserrat", "", 7.6)
    pdf.set_text_color(*_MUTED)
    notes = [
        "This receipt confirms payment for the membership above. Keep it for your records.",
    ]
    if biz["reg_line"]:
        notes.append(biz["reg_line"])
    notes.append("This is a system-generated document and is valid without a signature.")
    pdf.multi_cell(_CONTENT_W, 4.2, "\n".join(notes))


def render_invoice_pdf(payment: models.Payment, member: models.Member, plan, pet) -> tuple[bytes, str, str]:
    """Build the receipt PDF. Returns (pdf_bytes, invoice_number, filename)."""
    biz = _biz()
    inv_no = invoice_number(payment)

    pdf = _new_pdf()
    _header(pdf, biz)
    _title_block(pdf, biz, inv_no, payment)
    _parties_block(pdf, member, payment)
    _line_items(pdf, plan, pet, payment)
    _totals(pdf, biz, payment)
    _footer_note(pdf, biz)

    out = pdf.output()  # fpdf2 2.8 returns a bytearray
    filename = f"MetroPaws-Receipt-{inv_no}.pdf"
    return bytes(out), inv_no, filename
