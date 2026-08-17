"""_grant_plan's split between an activating payment and a later installment.

This is the money invariant of the whole monthly feature. grant_plan_to_pet
deletes and rebuilds a pet's benefits and resets plan_activated_at — and
wallet_usage windows on that timestamp — so re-granting on every installment
would give a monthly subscriber a fresh allowance twelve times a year while they
paid for one.
"""
from datetime import datetime, timedelta, timezone

import pytest

from app import models
from app.routers.payments import _grant_plan

MONTHLY_PRICE = 300


@pytest.fixture
def plan(make_plan):
    return make_plan(
        2999,
        price_monthly=MONTHLY_PRICE,
        reimbursement_wallet_centavos=200_000,
        emergency_wallet_centavos=30_000,
        vesting_planned_payments=6,
        vesting_emergency_payments=3,
    )


@pytest.fixture
def subscribed(db, plan, make_member, make_pet, days_ago):
    """A pet already activated by installment one, mid-run."""
    member = make_member()
    activated = days_ago(30)
    pet = make_pet(member, plan_id=plan.id, plan_activated_at=activated)
    subscription = models.Subscription(
        member_id=member.id,
        pet_id=pet.id,
        plan_id=plan.id,
        status=models.SubscriptionStatus.active,
        consecutive_payments=1,
        next_due_on=(datetime.now(timezone.utc) + timedelta(days=1)).date(),
    )
    db.add(subscription)
    db.flush()
    return member, pet, subscription, activated


def _installment(db, member, pet, plan, subscription) -> models.Payment:
    payment = models.Payment(
        member_id=member.id,
        plan_id=plan.id,
        pet_id=pet.id,
        amount_php=MONTHLY_PRICE,
        subscription_id=subscription.id,
        status=models.PaymentStatus.pending,
    )
    db.add(payment)
    db.flush()
    return payment


def test_a_later_installment_does_not_reset_the_wallet_year(db, plan, subscribed):
    """The whole point: plan_activated_at must not move, because wallet_usage
    windows on it and moving it hands back a spent allowance.

    Compares the stored value before and after rather than against the fixture's
    input — SQLite drops tzinfo on round-trip, so an aware/naive mismatch would
    fail this for a reason that has nothing to do with the invariant.
    """
    member, pet, subscription, _ = subscribed
    payment = _installment(db, member, pet, plan, subscription)
    db.refresh(pet)
    before = pet.plan_activated_at

    _grant_plan(db, payment)

    assert pet.plan_activated_at == before


def test_a_later_installment_advances_the_vesting_counter(db, plan, subscribed):
    member, pet, subscription, _ = subscribed

    _grant_plan(db, _installment(db, member, pet, plan, subscription))

    assert subscription.consecutive_payments == 2


def test_a_later_installment_is_marked_paid(db, plan, subscribed):
    member, pet, subscription, _ = subscribed
    payment = _installment(db, member, pet, plan, subscription)

    _grant_plan(db, payment)

    assert payment.status == models.PaymentStatus.paid


def test_a_later_installment_awards_no_paw_points(db, plan, subscribed):
    """Points mark joining or renewing. An installment is one payment toward a
    membership that already exists."""
    member, pet, subscription, _ = subscribed

    _grant_plan(db, _installment(db, member, pet, plan, subscription))

    awarded = (
        db.query(models.PawPointsTransaction)
        .filter(models.PawPointsTransaction.member_id == member.id)
        .count()
    )
    assert awarded == 0


def test_an_annual_payment_still_grants_the_plan(db, plan, make_member, make_pet):
    """No subscription_id means an ordinary purchase — the path that has always
    worked must be untouched."""
    member = make_member()
    pet = make_pet(member)
    payment = models.Payment(
        member_id=member.id,
        plan_id=plan.id,
        pet_id=pet.id,
        amount_php=2999,
        status=models.PaymentStatus.pending,
    )
    db.add(payment)
    db.flush()

    _grant_plan(db, payment)

    assert pet.plan_activated_at is not None


def test_granting_the_same_payment_twice_counts_it_once(db, plan, subscribed):
    """Four independent paths call _grant_plan and two can observe 'pending' at
    the same moment. Seen on dev 2026-08-17: a single ₱600 instalment ran the
    body twice and left the counter at 2, so the member vested twice as fast as
    they paid."""
    member, pet, subscription, _ = subscribed
    payment = _installment(db, member, pet, plan, subscription)

    _grant_plan(db, payment)
    _grant_plan(db, payment)

    assert subscription.consecutive_payments == 2


def test_granting_an_annual_payment_twice_does_not_move_activation(
    db, plan, make_member, make_pet
):
    """The same guard protects the annual path: grant_plan_to_pet rebuilds the
    pet's benefits and resets plan_activated_at, and wallet_usage windows on
    that — so a second run would hand back a spent allowance."""
    member = make_member()
    pet = make_pet(member)
    payment = models.Payment(
        member_id=member.id,
        plan_id=plan.id,
        pet_id=pet.id,
        amount_php=5999,
        status=models.PaymentStatus.pending,
    )
    db.add(payment)
    db.flush()

    _grant_plan(db, payment)
    first = pet.plan_activated_at
    _grant_plan(db, payment)

    assert pet.plan_activated_at == first
