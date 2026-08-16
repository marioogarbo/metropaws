"""The plan-start gate on claim dates — reimbursements._reject_before_plan_start.

Agreement §5.1 makes a service obtained before the membership effective date
non-payable. The gate matters more than an ordinary validation because
wallet_usage excludes pre-activation claims from the used and pending totals: a
claim that slips past this check can never fail the balance test and never
consumes benefit, so it is paid out of a pool it never touches.
"""
from datetime import date, timedelta

import pytest
from fastapi import HTTPException

from app.routers.reimbursements import _reject_before_plan_start

ACTIVATED = date(2026, 6, 1)


@pytest.fixture
def planned_pet(make_plan, make_member, make_pet, days_ago):
    """A pet whose plan started ACTIVATED days-with-a-fixed-date ago."""
    plan = make_plan(2999)
    member = make_member()
    activated_days_ago = (date.today() - ACTIVATED).days
    return make_pet(
        member,
        name="Luster",
        plan_id=plan.id,
        plan_activated_at=days_ago(activated_days_ago),
    )


def test_a_claim_dated_before_activation_is_rejected(planned_pet):
    with pytest.raises(HTTPException) as raised:
        _reject_before_plan_start(planned_pet, ACTIVATED - timedelta(days=1))

    assert raised.value.status_code == 400


def test_the_rejection_names_the_pet_and_the_start_date(planned_pet):
    with pytest.raises(HTTPException) as raised:
        _reject_before_plan_start(planned_pet, ACTIVATED - timedelta(days=1))

    assert "Luster" in raised.value.detail


def test_a_claim_dated_on_the_activation_day_is_allowed(planned_pet):
    """The boundary is inclusive — activation day is covered, matching
    wallet_usage's `service_date >= plan_activated_at`."""
    assert _reject_before_plan_start(planned_pet, ACTIVATED) is None


def test_a_claim_dated_after_activation_is_allowed(planned_pet):
    assert _reject_before_plan_start(planned_pet, ACTIVATED + timedelta(days=30)) is None


def test_a_legacy_grant_without_an_activation_date_is_not_gated(make_plan, make_member, make_pet):
    """plan_term_utils treats these as active with no expiry, so there is no term
    start to measure a claim against. Gating them would reject every claim from
    the manually-granted pets."""
    plan = make_plan(2999)
    pet = make_pet(make_member(), plan_id=plan.id, plan_activated_at=None)

    assert _reject_before_plan_start(pet, date(2020, 1, 1)) is None
