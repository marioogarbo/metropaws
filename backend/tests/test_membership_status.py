"""The §5.7 status labels — membership_status.

Agreement §5.7 makes the member responsible for checking this before requesting
a service, so a label that overstates their standing is the failure that matters:
it invites someone to incur a bill the plan will not pay.
"""
from datetime import timedelta

import pytest

from app import models
from app.domain.membership_status import MembershipStatus, label_for, status_for

PLANNED_THRESHOLD = 6
EMERGENCY_THRESHOLD = 3


@pytest.fixture
def monthly_plan(make_plan):
    return make_plan(
        2999,
        vesting_planned_payments=PLANNED_THRESHOLD,
        vesting_emergency_payments=EMERGENCY_THRESHOLD,
    )


@pytest.fixture
def annual_pet(db, make_plan, make_member, make_pet, days_ago):
    plan = make_plan(2999)
    member = make_member()
    return make_pet(member, plan_id=plan.id, plan_activated_at=days_ago(30)), member


@pytest.fixture
def monthly(db, monthly_plan, make_member, make_pet, days_ago):
    """(pet, subscription, member) for a monthly subscriber."""
    def _monthly(payments: int, **overrides):
        member = make_member(**overrides.pop("member", {}))
        pet = make_pet(member, plan_id=monthly_plan.id, plan_activated_at=days_ago(30))
        subscription = models.Subscription(
            member_id=member.id,
            pet_id=pet.id,
            plan_id=monthly_plan.id,
            status=overrides.pop("status", models.SubscriptionStatus.active),
            consecutive_payments=payments,
        )
        db.add(subscription)
        db.flush()
        return pet, subscription, member

    return _monthly


def test_a_pet_with_no_plan_is_pending_onboarding(db, make_member, make_pet):
    member = make_member()
    pet = make_pet(member)

    assert status_for(pet, None, member) is MembershipStatus.pending_onboarding


def test_an_annual_member_is_fully_eligible_immediately(annual_pet):
    """§5.9 — paying the annual fee skips vesting outright."""
    pet, member = annual_pet

    assert status_for(pet, None, member) is MembershipStatus.fully_service_eligible


def test_an_expired_plan_reads_expired(db, make_plan, make_member, make_pet, days_ago):
    plan = make_plan(2999)
    member = make_member()
    pet = make_pet(member, plan_id=plan.id, plan_activated_at=days_ago(400))

    assert status_for(pet, None, member) is MembershipStatus.expired


def test_a_subscriber_whose_first_payment_has_not_cleared_is_pending(monthly):
    """§5.3 grants digital access only AFTER the first cleared installment."""
    pet, subscription, member = monthly(payments=0)

    assert status_for(pet, subscription, member) is MembershipStatus.pending_onboarding


def test_one_cleared_payment_buys_digital_access_only(monthly):
    pet, subscription, member = monthly(payments=1)

    assert status_for(pet, subscription, member) is MembershipStatus.digital_access_active


def test_reaching_emergency_cover_reads_vesting_in_progress(monthly):
    pet, subscription, member = monthly(payments=EMERGENCY_THRESHOLD)

    assert status_for(pet, subscription, member) is MembershipStatus.vesting_in_progress


def test_the_payment_before_emergency_cover_is_still_digital_only(monthly):
    """Boundary: the label must not promise cover a payment early."""
    pet, subscription, member = monthly(payments=EMERGENCY_THRESHOLD - 1)

    assert status_for(pet, subscription, member) is MembershipStatus.digital_access_active


def test_reaching_the_planned_threshold_is_fully_eligible(monthly):
    pet, subscription, member = monthly(payments=PLANNED_THRESHOLD)

    assert status_for(pet, subscription, member) is MembershipStatus.fully_service_eligible


def test_the_payment_before_full_eligibility_is_still_vesting(monthly):
    pet, subscription, member = monthly(payments=PLANNED_THRESHOLD - 1)

    assert status_for(pet, subscription, member) is MembershipStatus.vesting_in_progress


def test_suspension_outranks_full_vesting(monthly):
    """§5.6 — a fully vested subscriber in default still cannot claim."""
    pet, subscription, member = monthly(
        payments=99, status=models.SubscriptionStatus.suspended
    )

    assert status_for(pet, subscription, member) is MembershipStatus.suspended


def test_a_restricted_member_reads_authorization_restricted(db, annual_pet):
    pet, member = annual_pet
    member.direct_pay_enabled = False
    db.flush()

    assert status_for(pet, None, member) is MembershipStatus.authorization_restricted


def test_an_unset_override_does_not_restrict(db, annual_pet):
    """NULL means "follow the global switch", not "restricted"."""
    pet, member = annual_pet
    member.direct_pay_enabled = None
    db.flush()

    assert status_for(pet, None, member) is MembershipStatus.fully_service_eligible


def test_expiry_outranks_a_restriction(db, make_plan, make_member, make_pet, days_ago):
    """The stronger obstacle wins: an expired plan blocks everything, while a
    restriction only narrows how a live plan may be used."""
    plan = make_plan(2999)
    member = make_member(direct_pay_enabled=False)
    pet = make_pet(member, plan_id=plan.id, plan_activated_at=days_ago(400))

    assert status_for(pet, None, member) is MembershipStatus.expired


def test_every_status_has_the_contract_wording(db):
    """The app renders label_for verbatim, so a missing entry would surface as a
    KeyError in front of a member."""
    assert all(label_for(status) for status in MembershipStatus)


def test_the_label_matches_the_agreement_text(db):
    assert label_for(MembershipStatus.fully_service_eligible) == "Fully Service-Eligible"
