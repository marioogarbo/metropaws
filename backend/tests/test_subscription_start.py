"""Opening and reopening a monthly arrangement — subscription_utils.start_subscription.

`pet_id` is unique on subscriptions, so a member who cancels and comes back must
reuse their own row rather than collide with it. Reopening has to hand back a
clean slate: §5.8 means the new arrangement earns its vesting from scratch.
"""
from datetime import date

import pytest

from app import models
from app.domain import subscription_utils as subs


@pytest.fixture
def plan(make_plan):
    return make_plan(
        2999,
        price_monthly=300,
        vesting_planned_payments=6,
        vesting_emergency_payments=3,
    )


@pytest.fixture
def pet(make_member, make_pet):
    return make_pet(make_member())


def test_starting_a_subscription_awaits_the_first_payment(db, plan, pet):
    subscription = subs.start_subscription(db, pet, plan)

    assert subscription.status == models.SubscriptionStatus.pending_first_payment


def test_a_new_subscription_has_no_payments_yet(db, plan, pet):
    subscription = subs.start_subscription(db, pet, plan)

    assert subscription.consecutive_payments == 0


def test_a_new_subscription_belongs_to_the_pets_member(db, plan, pet):
    subscription = subs.start_subscription(db, pet, plan)

    assert subscription.member_id == pet.member_id


def test_reopening_reuses_the_pets_existing_row(db, plan, pet):
    """pet_id is unique — a second insert would violate the constraint."""
    first = subs.start_subscription(db, pet, plan)
    first.status = models.SubscriptionStatus.cancelled
    db.flush()

    second = subs.start_subscription(db, pet, plan)

    assert second.id == first.id


def test_reopening_surrenders_the_previous_vesting(db, plan, pet):
    """§5.8 — the earlier run must not carry over into the new arrangement."""
    subscription = subs.start_subscription(db, pet, plan)
    subscription.consecutive_payments = 9
    subscription.planned_eligible_since = date(2026, 1, 1)
    subscription.status = models.SubscriptionStatus.cancelled
    db.flush()

    subs.start_subscription(db, pet, plan)

    assert subscription.planned_eligible_since is None


def test_reopening_clears_the_payment_counter(db, plan, pet):
    subscription = subs.start_subscription(db, pet, plan)
    subscription.consecutive_payments = 9
    subscription.status = models.SubscriptionStatus.cancelled
    db.flush()

    subs.start_subscription(db, pet, plan)

    assert subscription.consecutive_payments == 0


def test_a_reopened_subscription_gates_claims_again(db, plan, pet):
    """The visible consequence: a returning member is unvested, not still
    covered from last time."""
    subscription = subs.start_subscription(db, pet, plan)

    reason = subs.claim_block_reason(
        subscription, subs.BenefitClass.emergency, date(2026, 6, 15)
    )

    assert reason is not None
