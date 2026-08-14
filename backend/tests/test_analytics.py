"""Benefit utilization KPI — the peso ratio behind the dashboard tile.

The metric it replaced counted service sessions and therefore read 0% forever,
so the cases here pin what does and does not count as consumed benefit.
"""
from datetime import date, timedelta

from app import models
from app.domain import plan_term_utils
from app.routers.admin.analytics import benefit_utilization

PREVENTIVE_WALLET = 200_000  # ₱2,000 in centavos
EMERGENCY_WALLET = 30_000  # ₱300 in centavos


def _plan_with_wallets(make_plan) -> models.Plan:
    return make_plan(
        2999,
        reimbursement_wallet_centavos=PREVENTIVE_WALLET,
        emergency_wallet_centavos=EMERGENCY_WALLET,
    )


def _activated_pet(make_member, make_plan, make_pet, days_ago, days: int = 30) -> models.Pet:
    return make_pet(
        make_member(),
        plan_id=_plan_with_wallets(make_plan).id,
        plan_activated_at=days_ago(days),
    )


def test_no_plans_reports_zero_without_dividing(db):
    assert benefit_utilization(db) == {"used_php": 0, "granted_php": 0, "used_pct": 0.0}


def test_granted_total_sums_both_wallet_pools(db, make_member, make_plan, make_pet, days_ago):
    _activated_pet(make_member, make_plan, make_pet, days_ago)

    assert benefit_utilization(db)["granted_php"] == 2300


def test_paid_claim_counts_as_used(
    db, make_member, make_plan, make_pet, make_service_type, make_claim, days_ago
):
    pet = _activated_pet(make_member, make_plan, make_pet, days_ago)
    make_claim(
        pet,
        make_service_type("Vet Consultation"),
        models.ReimbursementStatus.paid,
        claimed_centavos=70_000,
        approved_centavos=65_000,
        service_date=date.today(),
    )

    assert benefit_utilization(db)["used_php"] == 650


def test_used_pct_is_the_peso_ratio(
    db, make_member, make_plan, make_pet, make_service_type, make_claim, days_ago
):
    pet = _activated_pet(make_member, make_plan, make_pet, days_ago)
    make_claim(
        pet,
        make_service_type("Vet Consultation"),
        models.ReimbursementStatus.paid,
        claimed_centavos=115_000,
        approved_centavos=115_000,
        service_date=date.today(),
    )

    assert benefit_utilization(db)["used_pct"] == 50.0


def test_pending_claim_does_not_count_as_used(
    db, make_member, make_plan, make_pet, make_service_type, make_claim, days_ago
):
    pet = _activated_pet(make_member, make_plan, make_pet, days_ago)
    make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.pending,
        claimed_centavos=50_000,
        service_date=date.today(),
    )

    assert benefit_utilization(db)["used_php"] == 0


def test_rejected_claim_does_not_count_as_used(
    db, make_member, make_plan, make_pet, make_service_type, make_claim, days_ago
):
    pet = _activated_pet(make_member, make_plan, make_pet, days_ago)
    make_claim(
        pet,
        make_service_type("Grooming"),
        models.ReimbursementStatus.rejected,
        claimed_centavos=50_000,
        approved_centavos=0,
        service_date=date.today(),
    )

    assert benefit_utilization(db)["used_php"] == 0


def test_claim_dated_before_activation_is_outside_the_term(
    db, make_member, make_plan, make_pet, make_service_type, make_claim, days_ago
):
    pet = _activated_pet(make_member, make_plan, make_pet, days_ago, days=30)
    make_claim(
        pet,
        make_service_type("Vet Consultation"),
        models.ReimbursementStatus.paid,
        claimed_centavos=40_000,
        approved_centavos=40_000,
        service_date=date.today() - timedelta(days=45),
    )

    assert benefit_utilization(db)["used_php"] == 0


def test_claim_dated_on_the_activation_day_counts(
    db, make_member, make_plan, make_pet, make_service_type, make_claim, days_ago
):
    pet = _activated_pet(make_member, make_plan, make_pet, days_ago, days=30)
    make_claim(
        pet,
        make_service_type("Vet Consultation"),
        models.ReimbursementStatus.paid,
        claimed_centavos=40_000,
        approved_centavos=40_000,
        service_date=date.today() - timedelta(days=30),
    )

    assert benefit_utilization(db)["used_php"] == 400


def test_expired_term_is_excluded_from_granted(
    db, make_member, make_plan, make_pet, days_ago
):
    _activated_pet(
        make_member, make_plan, make_pet, days_ago, days=plan_term_utils.PLAN_TERM_DAYS + 1
    )

    assert benefit_utilization(db)["granted_php"] == 0


def test_legacy_grant_without_an_activation_date_still_counts(
    db, make_member, make_plan, make_pet, make_service_type, make_claim
):
    pet = make_pet(
        make_member(), plan_id=_plan_with_wallets(make_plan).id, plan_activated_at=None
    )
    make_claim(
        pet,
        make_service_type("Vet Consultation"),
        models.ReimbursementStatus.approved,
        claimed_centavos=23_000,
        approved_centavos=23_000,
        service_date=date.today(),
    )

    assert benefit_utilization(db)["used_pct"] == 10.0


def test_pet_without_a_plan_grants_nothing(db, make_member, make_pet):
    make_pet(make_member(), plan_id=None, plan_activated_at=None)

    assert benefit_utilization(db)["granted_php"] == 0
