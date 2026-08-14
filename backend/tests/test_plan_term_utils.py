"""Plan term and purchase eligibility — plan_term_utils.

These rules decide whether a member is allowed to buy a plan at all, so a
regression here either blocks a legitimate sale or lets a member replace a
plan year whose benefits they have already spent. Tier comparison is by price,
matching pricing_utils.
"""
from datetime import date

import models
import plan_term_utils

PREMIUM_PRICE = 4999
STANDARD_PRICE = 2999
BASIC_PRICE = 1499

DAYS_IN_TERM = plan_term_utils.PLAN_TERM_DAYS


def _add_pet_service(db, pet, service_type, used_sessions: int) -> None:
    db.add(
        models.PetService(
            pet_id=pet.id,
            service_type_id=service_type.id,
            total_sessions=4,
            used_sessions=used_sessions,
        )
    )
    db.flush()


def _days_into_renewal_window() -> int:
    """Age of a plan that has just entered the renewal window."""
    return DAYS_IN_TERM - plan_term_utils.renewal_window_days() + 1


def test_pet_without_a_plan_has_no_status(db, make_member, make_pet):
    pet = make_pet(make_member(), plan_id=None)

    assert plan_term_utils.plan_status(pet) == "none"


def test_freshly_activated_plan_is_active(db, make_member, make_plan, make_pet, days_ago):
    pet = make_pet(make_member(), plan_id=make_plan(STANDARD_PRICE).id, plan_activated_at=days_ago(1))

    assert plan_term_utils.plan_status(pet) == "active"


def test_plan_enters_the_renewal_window_before_expiry(db, make_member, make_plan, make_pet, days_ago):
    """Boundary: the window is the final RENEWAL_WINDOW_DAYS of the term."""
    pet = make_pet(
        make_member(),
        plan_id=make_plan(STANDARD_PRICE).id,
        plan_activated_at=days_ago(_days_into_renewal_window()),
    )

    assert plan_term_utils.plan_status(pet) == "renewal_window"


def test_plan_just_outside_the_window_is_still_active(db, make_member, make_plan, make_pet, days_ago):
    """The other side of the same boundary, two days earlier."""
    pet = make_pet(
        make_member(),
        plan_id=make_plan(STANDARD_PRICE).id,
        plan_activated_at=days_ago(_days_into_renewal_window() - 2),
    )

    assert plan_term_utils.plan_status(pet) == "active"


def test_plan_expires_after_the_term(db, make_member, make_plan, make_pet, days_ago):
    pet = make_pet(
        make_member(),
        plan_id=make_plan(STANDARD_PRICE).id,
        plan_activated_at=days_ago(DAYS_IN_TERM + 1),
    )

    assert plan_term_utils.plan_status(pet) == "expired"


def test_legacy_plan_without_an_activation_date_never_expires(db, make_member, make_plan, make_pet):
    pet = make_pet(make_member(), plan_id=make_plan(STANDARD_PRICE).id, plan_activated_at=None)

    assert plan_term_utils.plan_status(pet) == "active"


def test_plan_term_is_none_for_a_legacy_plan(db, make_member, make_plan, make_pet):
    pet = make_pet(make_member(), plan_id=make_plan(STANDARD_PRICE).id, plan_activated_at=None)

    assert plan_term_utils.plan_term(pet) is None


def test_first_purchase_is_allowed_as_new(db, make_member, make_plan, make_pet):
    pet = make_pet(make_member(), plan_id=None)

    assert plan_term_utils.purchase_eligibility(db, pet, make_plan(STANDARD_PRICE)) == (True, "new")


def test_higher_plan_mid_term_is_an_upgrade(db, make_member, make_plan, make_pet, days_ago):
    pet = make_pet(make_member(), plan_id=make_plan(STANDARD_PRICE).id, plan_activated_at=days_ago(10))

    assert plan_term_utils.purchase_eligibility(db, pet, make_plan(PREMIUM_PRICE)) == (True, "upgrade")


def test_same_plan_mid_term_is_blocked(db, make_member, make_plan, make_pet, days_ago):
    plan = make_plan(STANDARD_PRICE)
    pet = make_pet(make_member(), plan_id=plan.id, plan_activated_at=days_ago(10))

    assert plan_term_utils.purchase_eligibility(db, pet, plan) == (False, "current_plan")


def test_cheaper_plan_mid_term_is_blocked(db, make_member, make_plan, make_pet, days_ago):
    pet = make_pet(make_member(), plan_id=make_plan(STANDARD_PRICE).id, plan_activated_at=days_ago(10))

    assert plan_term_utils.purchase_eligibility(db, pet, make_plan(BASIC_PRICE)) == (False, "lower_plan")


def test_different_plan_at_the_same_price_is_blocked(db, make_member, make_plan, make_pet, days_ago):
    """Boundary between upgrade and lower_plan: only STRICTLY higher qualifies."""
    pet = make_pet(make_member(), plan_id=make_plan(STANDARD_PRICE).id, plan_activated_at=days_ago(10))

    assert plan_term_utils.purchase_eligibility(db, pet, make_plan(STANDARD_PRICE)) == (False, "lower_plan")


def test_upgrade_is_blocked_once_a_session_is_used(
    db, make_member, make_plan, make_pet, make_service_type, days_ago
):
    pet = make_pet(make_member(), plan_id=make_plan(STANDARD_PRICE).id, plan_activated_at=days_ago(10))
    _add_pet_service(db, pet, make_service_type("Grooming"), used_sessions=1)

    assert plan_term_utils.purchase_eligibility(db, pet, make_plan(PREMIUM_PRICE)) == (False, "benefits_used")


def test_any_plan_is_allowed_in_the_renewal_window(db, make_member, make_plan, make_pet, days_ago):
    pet = make_pet(
        make_member(),
        plan_id=make_plan(STANDARD_PRICE).id,
        plan_activated_at=days_ago(_days_into_renewal_window()),
    )

    assert plan_term_utils.purchase_eligibility(db, pet, make_plan(BASIC_PRICE)) == (True, "renewal")


def test_any_plan_is_allowed_after_expiry(db, make_member, make_plan, make_pet, days_ago):
    pet = make_pet(
        make_member(),
        plan_id=make_plan(STANDARD_PRICE).id,
        plan_activated_at=days_ago(DAYS_IN_TERM + 1),
    )

    assert plan_term_utils.purchase_eligibility(db, pet, make_plan(BASIC_PRICE)) == (True, "renewal")


def test_renewal_ignores_used_benefits(
    db, make_member, make_plan, make_pet, make_service_type, days_ago
):
    """Untouched-benefits is an upgrade rule only — a renewal never has to meet it."""
    pet = make_pet(
        make_member(),
        plan_id=make_plan(STANDARD_PRICE).id,
        plan_activated_at=days_ago(DAYS_IN_TERM + 1),
    )
    _add_pet_service(db, pet, make_service_type("Grooming"), used_sessions=3)

    assert plan_term_utils.purchase_eligibility(db, pet, make_plan(PREMIUM_PRICE)) == (True, "renewal")


def test_benefits_are_untouched_when_nothing_is_used(
    db, make_member, make_plan, make_pet, make_service_type, days_ago
):
    pet = make_pet(make_member(), plan_id=make_plan(STANDARD_PRICE).id, plan_activated_at=days_ago(10))
    _add_pet_service(db, pet, make_service_type("Grooming"), used_sessions=0)

    assert plan_term_utils.benefits_untouched(db, pet) is True


def test_pending_claim_counts_as_touched_benefits(
    db, make_member, make_plan, make_pet, make_service_type, make_claim, days_ago
):
    """A claim awaiting review has reserved benefit, so an upgrade must wait."""
    pet = make_pet(make_member(), plan_id=make_plan(STANDARD_PRICE).id, plan_activated_at=days_ago(10))
    make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.pending,
        claimed_centavos=50_000,
        service_date=date.today(),
    )

    assert plan_term_utils.benefits_untouched(db, pet) is False


def test_rejected_claim_does_not_touch_benefits(
    db, make_member, make_plan, make_pet, make_service_type, make_claim, days_ago
):
    pet = make_pet(make_member(), plan_id=make_plan(STANDARD_PRICE).id, plan_activated_at=days_ago(10))
    make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.rejected,
        claimed_centavos=50_000,
        service_date=date.today(),
    )

    assert plan_term_utils.benefits_untouched(db, pet) is True


def test_unparseable_renewal_window_falls_back_to_the_default(monkeypatch):
    monkeypatch.setenv("RENEWAL_WINDOW_DAYS", "a month")

    assert plan_term_utils.renewal_window_days() == 30


def test_eligibility_message_names_the_renewal_window():
    message = plan_term_utils.eligibility_message("current_plan")

    assert str(plan_term_utils.renewal_window_days()) in message


def test_unknown_eligibility_code_still_returns_a_message():
    assert plan_term_utils.eligibility_message("no-such-code")
