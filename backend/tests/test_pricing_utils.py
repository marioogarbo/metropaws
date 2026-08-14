"""Pack Discount rules — pricing_utils.pack_discount_quote.

This is the money path: the value it returns is what the member is charged and
what gets snapshotted onto the Payment row. The published policy is 15% off the
annual plan for a member's 2nd and 3rd pet, only for a plan strictly cheaper
than the member's best active plan, and only on a pet's first activation.
"""
from domain import pricing_utils

PREMIUM_PRICE = 4999
STANDARD_PRICE = 2999
BASIC_PRICE = 1499


def _quote(db, member, plan, **kwargs):
    return pricing_utils.pack_discount_quote(db, member, plan, **kwargs)


def test_first_pet_pays_full_price(db, make_member, make_plan):
    member = make_member()
    plan = make_plan(STANDARD_PRICE)

    assert _quote(db, member, plan)["discount_php"] == 0


def test_second_pet_on_a_cheaper_plan_is_discounted(db, make_member, make_plan, make_pet):
    member = make_member()
    premium = make_plan(PREMIUM_PRICE)
    make_pet(member, plan_id=premium.id)

    assert _quote(db, member, make_plan(STANDARD_PRICE))["discount_percent"] == 15


def test_discount_rounds_in_the_members_favour(db, make_member, make_plan, make_pet):
    """15% of 2999 is 449.85; the member pays 2549, not 2550."""
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id)

    quote = _quote(db, member, make_plan(STANDARD_PRICE))

    assert (quote["full_php"], quote["discount_php"], quote["final_php"]) == (2999, 450, 2549)


def test_equal_priced_plan_is_not_discounted(db, make_member, make_plan, make_pet):
    """The boundary: the policy says succeeding LOWER plans, so equal pays full."""
    member = make_member()
    make_pet(member, plan_id=make_plan(STANDARD_PRICE).id)

    assert _quote(db, member, make_plan(STANDARD_PRICE))["discount_php"] == 0


def test_more_expensive_plan_is_not_discounted(db, make_member, make_plan, make_pet):
    member = make_member()
    make_pet(member, plan_id=make_plan(STANDARD_PRICE).id)

    assert _quote(db, member, make_plan(PREMIUM_PRICE))["discount_php"] == 0


def test_third_pet_is_still_discounted(db, make_member, make_plan, make_pet):
    member = make_member()
    premium = make_plan(PREMIUM_PRICE)
    make_pet(member, plan_id=premium.id)
    make_pet(member, plan_id=make_plan(STANDARD_PRICE).id)

    assert _quote(db, member, make_plan(BASIC_PRICE))["discount_percent"] == 15


def test_fourth_pet_pays_full_price(db, make_member, make_plan, make_pet):
    """The other side of the same boundary — three existing plans is the cap."""
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id)
    make_pet(member, plan_id=make_plan(STANDARD_PRICE).id)
    make_pet(member, plan_id=make_plan(STANDARD_PRICE).id)

    assert _quote(db, member, make_plan(BASIC_PRICE))["discount_php"] == 0


def test_upgrade_pays_full_price(db, make_member, make_plan, make_pet):
    """First activation only — an upgrade is not a joining incentive."""
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id)

    quote = _quote(db, member, make_plan(STANDARD_PRICE), purchase_code="upgrade")

    assert quote["discount_php"] == 0


def test_renewal_pays_full_price(db, make_member, make_plan, make_pet):
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id)

    quote = _quote(db, member, make_plan(STANDARD_PRICE), purchase_code="renewal")

    assert quote["discount_php"] == 0


def test_new_purchase_keeps_the_discount(db, make_member, make_plan, make_pet):
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id)

    quote = _quote(db, member, make_plan(STANDARD_PRICE), purchase_code="new")

    assert quote["discount_percent"] == 15


def test_missing_purchase_context_keeps_the_discount(db, make_member, make_plan, make_pet):
    """A caller that doesn't know the code must not silently lose the discount."""
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id)

    quote = _quote(db, member, make_plan(STANDARD_PRICE), purchase_code=None)

    assert quote["discount_percent"] == 15


def test_admin_can_switch_the_discount_off(db, make_member, make_plan, make_pet, set_app_setting):
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id)
    set_app_setting(pricing_utils.PACK_DISCOUNT_ENABLED_KEY, "false")

    assert _quote(db, member, make_plan(STANDARD_PRICE))["discount_php"] == 0


def test_admin_percent_is_applied(db, make_member, make_plan, make_pet, set_app_setting):
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id)
    set_app_setting(pricing_utils.PACK_DISCOUNT_PERCENT_KEY, "20")

    assert _quote(db, member, make_plan(STANDARD_PRICE))["discount_percent"] == 20


def test_zero_percent_is_treated_as_no_discount(db, make_member, make_plan, make_pet, set_app_setting):
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id)
    set_app_setting(pricing_utils.PACK_DISCOUNT_PERCENT_KEY, "0")

    assert _quote(db, member, make_plan(STANDARD_PRICE))["discount_php"] == 0


def test_a_pet_does_not_anchor_its_own_renewal(db, make_member, make_plan, make_pet):
    """exclude_pet_id keeps the pet being paid for out of the anchor set."""
    member = make_member()
    only_pet = make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id)

    quote = _quote(db, member, make_plan(STANDARD_PRICE), exclude_pet_id=only_pet.id)

    assert quote["discount_php"] == 0


def test_expired_anchor_plan_does_not_earn_a_discount(db, make_member, make_plan, make_pet, days_ago):
    """A plan activated more than 365 days ago is no longer an anchor."""
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id, plan_activated_at=days_ago(366))

    assert _quote(db, member, make_plan(STANDARD_PRICE))["discount_php"] == 0


def test_anchor_inside_the_year_still_earns_a_discount(db, make_member, make_plan, make_pet, days_ago):
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id, plan_activated_at=days_ago(364))

    assert _quote(db, member, make_plan(STANDARD_PRICE))["discount_percent"] == 15


def test_legacy_anchor_without_an_activation_date_counts_as_active(db, make_member, make_plan, make_pet):
    """Manual/seeded grants predate plan_activated_at and must not lose the
    published discount on a technicality."""
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id, plan_activated_at=None)

    assert _quote(db, member, make_plan(STANDARD_PRICE))["discount_percent"] == 15


def test_unparseable_admin_percent_falls_back_to_the_default(
    db, make_member, make_plan, make_pet, set_app_setting
):
    """A bad AppSetting value must not take the money path down with it."""
    member = make_member()
    make_pet(member, plan_id=make_plan(PREMIUM_PRICE).id)
    set_app_setting(pricing_utils.PACK_DISCOUNT_PERCENT_KEY, "fifteen")

    assert _quote(db, member, make_plan(STANDARD_PRICE))["discount_percent"] == 15


def test_unparseable_env_percent_falls_back_to_the_default(monkeypatch):
    monkeypatch.setenv("PACK_DISCOUNT_PERCENT", "lots")

    assert pricing_utils._default_percent_from_env() == 15


def test_unparseable_env_pet_cap_falls_back_to_the_default(monkeypatch):
    monkeypatch.setenv("PACK_DISCOUNT_MAX_PLAN_PETS", "three")

    assert pricing_utils._max_plan_pets() == 3


def test_another_members_pet_is_not_an_anchor(db, make_member, make_plan, make_pet):
    make_pet(make_member(), plan_id=make_plan(PREMIUM_PRICE).id)
    buyer = make_member()

    assert _quote(db, buyer, make_plan(STANDARD_PRICE))["discount_php"] == 0


def test_pet_without_a_plan_is_not_an_anchor(db, make_member, make_plan, make_pet):
    member = make_member()
    make_pet(member, plan_id=None)

    assert _quote(db, member, make_plan(STANDARD_PRICE))["discount_php"] == 0
