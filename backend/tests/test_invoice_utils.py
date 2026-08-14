"""Receipt generation — invoice_utils.

The rendering test exists because of a real escape: splitting this module into a
package moved `__file__`, and the `__file__`-relative asset path started looking
for the bundled fonts inside invoice_utils/ instead of backend/. Every receipt
would have raised FileNotFoundError, and the whole suite still passed, because
nothing rendered a PDF. Now something does.
"""
from datetime import datetime, timezone
from pathlib import Path

from app import models
from app.invoice_utils import formatting, render

PAID_AT = datetime(2026, 8, 14, 3, 25, tzinfo=timezone.utc)
CREATED_AT = datetime(2026, 8, 14, 3, 21, tzinfo=timezone.utc)
PAYMENT_ID = "abcd1234-ffff-0000-1111-222233334444"


def _payment(**overrides) -> models.Payment:
    fields = {
        "id": PAYMENT_ID,
        "amount_php": 4999,
        "discount_php": 0,
        "currency": "PHP",
        # Not "paymongo": that path calls the live API to learn which wallet was
        # used, which a test must not do.
        "provider": "manual",
        "created_at": CREATED_AT,
        "paid_at": PAID_AT,
    }
    fields.update(overrides)
    return models.Payment(**fields)


def _member() -> models.Member:
    member = models.Member(
        first_name="Maria",
        last_name="Santos",
        phone="9171234567",
        address="18 Apollo III, Talon Singko",
    )
    member.user = models.User(email="maria@example.test", password_hash="x")
    return member


def _plan() -> models.Plan:
    return models.Plan(name="Premium", price=4999, features=[])


def _pet() -> models.Pet:
    return models.Pet(name="Bantay", breed="Aspin", birth_month=1, birth_year=2020, weight_kg=10.0)


def test_bundled_fonts_resolve():
    """The exact failure the split introduced: the asset path must point at
    backend/assets, wherever this module happens to live."""
    fonts = Path(render._FONTS_DIR)

    assert fonts.is_dir()
    assert (fonts / "Montserrat-Regular.ttf").is_file()


def test_logo_resolves():
    assert Path(render._LOGO_PATH).is_file()


def test_receipt_renders_a_pdf():
    pdf_bytes, _invoice_no, _filename = render.render_invoice_pdf(
        _payment(), _member(), _plan(), _pet()
    )

    assert pdf_bytes.startswith(b"%PDF")


def test_rendered_receipt_is_a_full_document():
    """A receipt that lost its fonts or logo would still be a valid PDF, just a
    tiny one — size is the cheapest guard against silently losing the assets."""
    pdf_bytes, _invoice_no, _filename = render.render_invoice_pdf(
        _payment(), _member(), _plan(), _pet()
    )

    assert len(pdf_bytes) > 20_000


def test_receipt_filename_carries_the_invoice_number():
    _pdf_bytes, invoice_no, filename = render.render_invoice_pdf(
        _payment(), _member(), _plan(), _pet()
    )

    assert filename == f"MetroPaws-Receipt-{invoice_no}.pdf"


def test_a_discounted_receipt_renders():
    """The Pack Discount adds a subtotal/discount/total block — a different path
    through _totals than a full-price payment."""
    pdf_bytes, _invoice_no, _filename = render.render_invoice_pdf(
        _payment(amount_php=2549, discount_php=450), _member(), _plan(), _pet()
    )

    assert pdf_bytes.startswith(b"%PDF")


def test_receipt_renders_without_a_pet():
    """Legacy member-level payments have no pet attached."""
    pdf_bytes, _invoice_no, _filename = render.render_invoice_pdf(
        _payment(), _member(), _plan(), None
    )

    assert pdf_bytes.startswith(b"%PDF")


def test_invoice_number_is_stable_for_a_payment():
    """A resend must reproduce the same number, so it is derived, not sequential."""
    payment = _payment()

    assert formatting.invoice_number(payment) == formatting.invoice_number(payment)


def test_invoice_number_uses_the_year_and_payment_id():
    assert formatting.invoice_number(_payment()) == "MP-2026-ABCD1234"


def test_peso_amounts_print_the_iso_code_not_the_glyph():
    """The bundled Montserrat weights have no U+20B1; a formal document must
    never risk a missing-glyph box."""
    printed = formatting._php(1500)

    assert "PHP" in printed
    assert "₱" not in printed


def test_local_mobile_numbers_are_formatted():
    assert formatting._format_ph_phone("9171234567") == "+63 917 123 4567"


def test_unrecognised_phone_is_left_alone():
    assert formatting._format_ph_phone("not-a-number") == "not-a-number"


def test_missing_phone_renders_as_empty():
    assert formatting._format_ph_phone(None) == ""
