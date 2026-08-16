"""Monthly vesting rules — subscription_utils (Agreement Rev. 5A §5.2–§5.8).

These decide whether a monthly subscriber may draw benefit at all, so a wrong
answer either hands out money the member has not vested into or refuses someone
who has paid for it.
"""
from datetime import date

import pytest

from app import models
from app.domain import subscription_utils as subs

STANDARD_PLANNED = 6
STANDARD_EMERGENCY = 3
SERVICE_DAY = date(2026, 6, 15)


@pytest.fixture
def monthly_plan(make_plan):
    return make_plan(
        2999,
        vesting_planned_payments=STANDARD_PLANNED,
        vesting_emergency_payments=STANDARD_EMERGENCY,
    )


@pytest.fixture
def make_subscription(db, make_member, make_pet):
    def _make_subscription(plan, **overrides) -> models.Subscription:
        member = make_member()
        pet = make_pet(member, plan_id=plan.id)
        subscription = models.Subscription(
            member_id=member.id,
            pet_id=pet.id,
            plan_id=plan.id,
            status=overrides.pop("status", models.SubscriptionStatus.active),
            **overrides,
        )
        db.add(subscription)
        db.flush()
        return subscription

    return _make_subscription


def test_a_pet_paid_annually_has_no_subscription(db, make_member, make_pet):
    """§5.9 in code: an annual member simply has no row, so nothing gates them."""
    pet = make_pet(make_member())

    assert subs.for_pet(db, pet) is None


def test_a_cancelled_subscription_no_longer_gates(db, monthly_plan, make_subscription):
    subscription = make_subscription(
        monthly_plan, status=models.SubscriptionStatus.cancelled
    )
    pet = subscription.pet

    assert subs.for_pet(db, pet) is None


def test_an_emergency_category_answers_to_the_emergency_threshold(db):
    assert (
        subs.benefit_class_for_category("Emergency Stabilization")
        is subs.BenefitClass.emergency
    )


def test_any_other_category_answers_to_the_planned_threshold(db):
    assert subs.benefit_class_for_category("Grooming") is subs.BenefitClass.planned


def test_emergency_opens_before_planned_services(db, monthly_plan):
    """The ordering the §5.5 table's numerals produce, and the reason the
    contradicting words are not the intended reading."""
    emergency = subs.threshold(monthly_plan, subs.BenefitClass.emergency)
    planned = subs.threshold(monthly_plan, subs.BenefitClass.planned)

    assert emergency < planned


def test_a_plan_with_no_thresholds_gates_nothing(db, make_plan):
    plan = make_plan(2999)

    assert subs.threshold(plan, subs.BenefitClass.planned) == 0


def test_payments_remaining_counts_down(db, monthly_plan, make_subscription):
    subscription = make_subscription(monthly_plan, consecutive_payments=1)

    assert subs.payments_remaining(subscription, subs.BenefitClass.emergency) == 2


def test_payments_remaining_never_goes_negative(db, monthly_plan, make_subscription):
    subscription = make_subscription(monthly_plan, consecutive_payments=99)

    assert subs.payments_remaining(subscription, subs.BenefitClass.emergency) == 0


def test_the_third_payment_stamps_emergency_eligibility(db, monthly_plan, make_subscription):
    subscription = make_subscription(monthly_plan, consecutive_payments=2)

    subs.record_cleared_payment(subscription, SERVICE_DAY)

    assert subscription.emergency_eligible_since == SERVICE_DAY


def test_the_third_payment_does_not_stamp_planned_eligibility(db, monthly_plan, make_subscription):
    subscription = make_subscription(monthly_plan, consecutive_payments=2)

    subs.record_cleared_payment(subscription, SERVICE_DAY)

    assert subscription.planned_eligible_since is None


def test_the_sixth_payment_stamps_planned_eligibility(db, monthly_plan, make_subscription):
    subscription = make_subscription(monthly_plan, consecutive_payments=5)

    subs.record_cleared_payment(subscription, SERVICE_DAY)

    assert subscription.planned_eligible_since == SERVICE_DAY


def test_a_later_payment_does_not_move_an_existing_stamp(db, monthly_plan, make_subscription):
    """§5.8 hangs off this date, so re-stamping it would silently re-open a
    window that has already closed."""
    first_stamp = date(2026, 3, 1)
    subscription = make_subscription(
        monthly_plan, consecutive_payments=4, emergency_eligible_since=first_stamp
    )

    subs.record_cleared_payment(subscription, SERVICE_DAY)

    assert subscription.emergency_eligible_since == first_stamp


def test_a_cleared_payment_activates_a_pending_subscription(db, monthly_plan, make_subscription):
    subscription = make_subscription(
        monthly_plan, status=models.SubscriptionStatus.pending_first_payment
    )

    subs.record_cleared_payment(subscription, SERVICE_DAY)

    assert subscription.status == models.SubscriptionStatus.active


def test_an_unvested_claim_is_blocked(db, monthly_plan, make_subscription):
    subscription = make_subscription(monthly_plan, consecutive_payments=1)

    reason = subs.claim_block_reason(
        subscription, subs.BenefitClass.emergency, SERVICE_DAY
    )

    assert reason is not None


def test_the_block_says_how_many_payments_remain(db, monthly_plan, make_subscription):
    subscription = make_subscription(monthly_plan, consecutive_payments=1)

    reason = subs.claim_block_reason(
        subscription, subs.BenefitClass.emergency, SERVICE_DAY
    )

    assert "2 more payments" in reason


def test_the_block_reads_singular_for_the_last_payment(db, monthly_plan, make_subscription):
    subscription = make_subscription(monthly_plan, consecutive_payments=2)

    reason = subs.claim_block_reason(
        subscription, subs.BenefitClass.emergency, SERVICE_DAY
    )

    assert "1 more payment to go" in reason


def test_a_vested_claim_is_allowed(db, monthly_plan, make_subscription):
    subscription = make_subscription(
        monthly_plan,
        consecutive_payments=STANDARD_EMERGENCY,
        emergency_eligible_since=SERVICE_DAY,
    )

    assert (
        subs.claim_block_reason(subscription, subs.BenefitClass.emergency, SERVICE_DAY)
        is None
    )


def test_emergency_vesting_does_not_unlock_planned_services(db, monthly_plan, make_subscription):
    """The two thresholds are independent — three payments buy emergency cover
    and nothing else."""
    subscription = make_subscription(
        monthly_plan,
        consecutive_payments=STANDARD_EMERGENCY,
        emergency_eligible_since=SERVICE_DAY,
    )

    reason = subs.claim_block_reason(
        subscription, subs.BenefitClass.planned, SERVICE_DAY
    )

    assert reason is not None


def test_a_service_before_the_eligibility_date_is_refused(db, monthly_plan, make_subscription):
    """§5.8: completing the payments later does not make an earlier service
    payable."""
    subscription = make_subscription(
        monthly_plan,
        consecutive_payments=STANDARD_EMERGENCY,
        emergency_eligible_since=date(2026, 6, 10),
    )

    reason = subs.claim_block_reason(
        subscription, subs.BenefitClass.emergency, date(2026, 6, 9)
    )

    assert reason is not None


def test_a_service_on_the_eligibility_date_is_allowed(db, monthly_plan, make_subscription):
    """Inclusive boundary, matching every other date gate in the claim path."""
    began = date(2026, 6, 10)
    subscription = make_subscription(
        monthly_plan,
        consecutive_payments=STANDARD_EMERGENCY,
        emergency_eligible_since=began,
    )

    assert (
        subs.claim_block_reason(subscription, subs.BenefitClass.emergency, began) is None
    )


def test_a_suspended_subscription_blocks_even_when_vested(db, monthly_plan, make_subscription):
    """§5.6 — suspension outranks vesting."""
    subscription = make_subscription(
        monthly_plan,
        status=models.SubscriptionStatus.suspended,
        consecutive_payments=99,
        emergency_eligible_since=date(2026, 1, 1),
    )

    reason = subs.claim_block_reason(
        subscription, subs.BenefitClass.emergency, SERVICE_DAY
    )

    assert "suspended" in reason
