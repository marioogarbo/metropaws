"""Reimbursement wallet maths and eligibility — reimbursement_utils.

Every amount here is integer centavos. wallet_usage decides how much benefit a
member has left, so mis-bucketing a claim either hands out money twice or
refuses a valid claim.
"""
from datetime import date

import models
from domain import reimbursement_utils as rutils

GROOMING_CLAIM_CENTAVOS = 150_000
EMERGENCY_CLAIM_CENTAVOS = 500_000


def test_emergency_category_is_matched_exactly(db):
    assert rutils.is_emergency_category("Emergency") is True


def test_emergency_match_ignores_case_and_padding(db):
    assert rutils.is_emergency_category("  emergency ") is True


def test_missing_category_is_not_emergency(db):
    assert rutils.is_emergency_category(None) is False


def test_emergency_stabilization_does_not_match_the_emergency_pool(db):
    """Documents a live gap, it does not endorse it: the seeded category is
    named "Emergency Stabilization", but the pool matches the exact name
    "Emergency" only — so nothing currently draws from the Emergency Wallet.
    See context/ for the open decision on whether to rename or widen the match.
    """
    assert rutils.is_emergency_category("Emergency Stabilization") is False


def test_non_emergency_category_allows_direct_pay(db):
    assert rutils.is_direct_pay_eligible_category("Grooming") is True


def test_emergency_category_forbids_direct_pay(db):
    """Emergencies stay on pay-then-reimburse — manual review is too slow."""
    assert rutils.is_direct_pay_eligible_category("Emergency") is False


def test_member_without_an_override_follows_the_global_switch(db, make_member):
    member = make_member(direct_pay_enabled=None)

    assert rutils.is_direct_pay_available(member, global_enabled=True) is True


def test_member_override_can_restrict_one_member(db, make_member):
    """Restricting an abuser must not require switching the feature off for all."""
    member = make_member(direct_pay_enabled=False)

    assert rutils.is_direct_pay_available(member, global_enabled=True) is False


def test_member_override_can_enable_ahead_of_the_global_switch(db, make_member):
    member = make_member(direct_pay_enabled=True)

    assert rutils.is_direct_pay_available(member, global_enabled=False) is True


def test_plan_wallet_is_zero_without_a_plan(db):
    assert rutils.plan_wallet_centavos(db, None) == 0


def test_plan_wallet_reads_the_preventive_pool(db, make_plan):
    plan = make_plan(2999, reimbursement_wallet_centavos=800_000)

    assert rutils.plan_wallet_centavos(db, plan.id) == 800_000


def test_emergency_wallet_reads_the_emergency_pool(db, make_plan):
    plan = make_plan(2999, emergency_wallet_centavos=1_000_000)

    assert rutils.plan_emergency_wallet_centavos(db, plan.id) == 1_000_000


def test_unknown_plan_id_has_no_wallet(db):
    assert rutils.plan_wallet_centavos(db, "no-such-plan") == 0


def test_emergency_wallet_is_zero_without_a_plan(db):
    assert rutils.plan_emergency_wallet_centavos(db, None) == 0


def test_pet_with_no_claims_has_used_nothing(db, make_member, make_pet):
    pet = make_pet(make_member())

    assert rutils.wallet_usage(db, pet) == (0, 0, 0, 0)


def test_approved_claim_counts_as_used(db, make_member, make_pet, make_service_type, make_claim):
    pet = make_pet(make_member())
    make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.approved,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
        approved_centavos=100_000,
    )

    assert rutils.wallet_usage(db, pet) == (100_000, 0, 0, 0)


def test_paid_claim_counts_as_used(db, make_member, make_pet, make_service_type, make_claim):
    pet = make_pet(make_member())
    make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.paid,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
        approved_centavos=GROOMING_CLAIM_CENTAVOS,
    )

    assert rutils.wallet_usage(db, pet) == (GROOMING_CLAIM_CENTAVOS, 0, 0, 0)


def test_pending_claim_counts_as_pending(db, make_member, make_pet, make_service_type, make_claim):
    """Pending reserves the CLAIMED amount — nothing is approved yet."""
    pet = make_pet(make_member())
    make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.pending,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
    )

    assert rutils.wallet_usage(db, pet) == (0, GROOMING_CLAIM_CENTAVOS, 0, 0)


def test_needs_info_claim_still_reserves_benefit(db, make_member, make_pet, make_service_type, make_claim):
    pet = make_pet(make_member())
    make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.needs_info,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
    )

    assert rutils.wallet_usage(db, pet) == (0, GROOMING_CLAIM_CENTAVOS, 0, 0)


def test_rejected_claim_reserves_nothing(db, make_member, make_pet, make_service_type, make_claim):
    pet = make_pet(make_member())
    make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.rejected,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
    )

    assert rutils.wallet_usage(db, pet) == (0, 0, 0, 0)


def test_emergency_claim_draws_from_the_emergency_pool(db, make_member, make_pet, make_service_type, make_claim):
    pet = make_pet(make_member())
    make_claim(
        pet,
        make_service_type("Emergency"),
        models.ReimbursementStatus.approved,
        claimed_centavos=EMERGENCY_CLAIM_CENTAVOS,
        approved_centavos=EMERGENCY_CLAIM_CENTAVOS,
    )

    assert rutils.wallet_usage(db, pet) == (0, 0, EMERGENCY_CLAIM_CENTAVOS, 0)


def test_the_two_pools_are_tracked_separately(db, make_member, make_pet, make_service_type, make_claim):
    pet = make_pet(make_member())
    make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.approved,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
        approved_centavos=GROOMING_CLAIM_CENTAVOS,
    )
    make_claim(
        pet,
        make_service_type("Emergency"),
        models.ReimbursementStatus.pending,
        claimed_centavos=EMERGENCY_CLAIM_CENTAVOS,
    )

    assert rutils.wallet_usage(db, pet) == (GROOMING_CLAIM_CENTAVOS, 0, 0, EMERGENCY_CLAIM_CENTAVOS)


def test_claims_before_plan_activation_do_not_count(
    db, make_member, make_pet, make_service_type, make_claim, days_ago
):
    """The benefit period starts at activation — last year's claims are spent
    against last year's wallet."""
    pet = make_pet(make_member(), plan_activated_at=days_ago(30))
    make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.approved,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
        approved_centavos=GROOMING_CLAIM_CENTAVOS,
        service_date=date(2020, 1, 1),
    )

    assert rutils.wallet_usage(db, pet) == (0, 0, 0, 0)


def test_an_excluded_claim_is_left_out(db, make_member, make_pet, make_service_type, make_claim):
    """Approving a claim excludes itself so it isn't counted against its own cap."""
    pet = make_pet(make_member())
    claim = make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.pending,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
    )

    assert rutils.wallet_usage(db, pet, exclude_id=claim.id) == (0, 0, 0, 0)


def test_peso_formatting_uses_thousand_separators(db):
    assert rutils._peso(150_000) == "₱1,500.00"


def test_peso_formatting_handles_a_missing_amount(db):
    """approved_amount_centavos is NULL until an admin approves."""
    assert rutils._peso(None) == "₱0.00"


def _notification(claim, status: str) -> tuple[str, str]:
    return rutils._notification_content(claim, status, service="Grooming")


def test_approved_member_claim_names_the_approved_amount(
    db, make_member, make_pet, make_service_type, make_claim
):
    claim = make_claim(
        make_pet(make_member()),
        make_service_type("Grooming"),
        models.ReimbursementStatus.approved,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
        approved_centavos=100_000,
    )

    _title, body = _notification(claim, "approved")

    assert "₱1,000.00" in body


def test_approved_direct_pay_claim_names_the_provider(
    db, make_member, make_pet, make_service_type, make_claim
):
    claim = make_claim(
        make_pet(make_member()),
        make_service_type("Grooming"),
        models.ReimbursementStatus.approved,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
        approved_centavos=100_000,
    )
    claim.payout_target = models.PayoutTarget.provider
    claim.provider_name = "Happy Paws Clinic"

    _title, body = _notification(claim, "approved")

    assert "Happy Paws Clinic" in body


def test_paid_direct_pay_claim_tells_the_member_not_to_bring_cash(
    db, make_member, make_pet, make_service_type, make_claim
):
    claim = make_claim(
        make_pet(make_member()),
        make_service_type("Grooming"),
        models.ReimbursementStatus.paid,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
        approved_centavos=GROOMING_CLAIM_CENTAVOS,
    )
    claim.payout_target = models.PayoutTarget.provider
    claim.provider_name = "Happy Paws Clinic"

    _title, body = _notification(claim, "paid")

    assert "no need to bring cash" in body


def test_paid_member_claim_announces_the_payout(
    db, make_member, make_pet, make_service_type, make_claim
):
    claim = make_claim(
        make_pet(make_member()),
        make_service_type("Grooming"),
        models.ReimbursementStatus.paid,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
        approved_centavos=GROOMING_CLAIM_CENTAVOS,
    )

    title, body = _notification(claim, "paid")

    assert title == "Reimbursement released"
    assert "₱1,500.00" in body


def test_needs_info_notification_passes_on_the_admin_note(
    db, make_member, make_pet, make_service_type, make_claim
):
    claim = make_claim(
        make_pet(make_member()),
        make_service_type("Grooming"),
        models.ReimbursementStatus.needs_info,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
    )
    claim.admin_notes = "Receipt is cut off at the total."

    _title, body = _notification(claim, "needs_info")

    assert "Receipt is cut off at the total." in body


def test_rejected_notification_gives_the_reason(
    db, make_member, make_pet, make_service_type, make_claim
):
    claim = make_claim(
        make_pet(make_member()),
        make_service_type("Grooming"),
        models.ReimbursementStatus.rejected,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
    )
    claim.admin_notes = "Service date is outside the plan year."

    _title, body = _notification(claim, "rejected")

    assert "Service date is outside the plan year." in body


def test_unknown_status_still_produces_a_notification(
    db, make_member, make_pet, make_service_type, make_claim
):
    """A new status must never crash the notifier."""
    claim = make_claim(
        make_pet(make_member()),
        make_service_type("Grooming"),
        models.ReimbursementStatus.pending,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
    )

    title, body = _notification(claim, "under_review")

    assert title and body


def test_locking_usage_returns_the_same_totals(db, make_member, make_pet, make_service_type, make_claim):
    """Approval reads usage under a row lock; the maths must not change with it."""
    pet = make_pet(make_member())
    make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.approved,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
        approved_centavos=GROOMING_CLAIM_CENTAVOS,
    )

    assert rutils.wallet_usage(db, pet, lock=True) == rutils.wallet_usage(db, pet)


def test_another_pets_claims_are_not_counted(db, make_member, make_pet, make_service_type, make_claim):
    member = make_member()
    claiming_pet = make_pet(member)
    other_pet = make_pet(member)
    make_claim(
        other_pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.approved,
        claimed_centavos=GROOMING_CLAIM_CENTAVOS,
        approved_centavos=GROOMING_CLAIM_CENTAVOS,
    )

    assert rutils.wallet_usage(db, claiming_pet) == (0, 0, 0, 0)
