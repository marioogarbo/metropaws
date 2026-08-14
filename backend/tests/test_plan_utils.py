"""Granting a plan — plan_utils.

This is what a member receives for their money, so the rules are pinned here
before the function is ever restructured. The headline one is replace, not
top-up: every grant resets a pet to exactly the new plan's sessions and forfeits
whatever was left of the old term (client decision 2026-07-27). Getting that
backwards would silently hand out double benefits on renewal.

Note the asymmetry with grant_plan_to_member, which genuinely does top up.
"""
from datetime import datetime, timedelta, timezone

import models
import plan_utils

PREMIUM_PRICE = 4999
STANDARD_PRICE = 2999
PLAN_TERM_DAYS = 365


def _add_plan_service(db, plan, service_type, sessions: int) -> None:
    db.add(
        models.PlanService(
            plan_id=plan.id,
            service_type_id=service_type.id,
            sessions=sessions,
            reimbursement_cap_centavos=0,
        )
    )
    db.flush()


def _pet_services(db, pet) -> dict[str, int]:
    """{service type name: total_sessions} for a pet.

    Flushes first: the session runs with autoflush=False (as the app's does), so
    rows the grant only added stay invisible to a query until pushed. The app
    commits after granting, which has the same effect.
    """
    db.flush()
    rows = (
        db.query(models.PetService, models.ServiceType)
        .join(models.ServiceType, models.PetService.service_type_id == models.ServiceType.id)
        .filter(models.PetService.pet_id == pet.id)
        .all()
    )
    return {service_type.name: pet_service.total_sessions for pet_service, service_type in rows}


def test_granting_records_the_plan_on_the_pet(db, make_member, make_plan, make_pet):
    member = make_member()
    pet = make_pet(member)
    plan = make_plan(STANDARD_PRICE, name="Standard")

    plan_utils.grant_plan_to_pet(db, pet, plan, member)

    assert (pet.plan_id, pet.plan_type) == (plan.id, "Standard")


def test_granting_stamps_the_activation_time(db, make_member, make_plan, make_pet):
    """wallet_usage windows claims on this, so a grant resets the benefit year."""
    member = make_member()
    pet = make_pet(member, plan_activated_at=None)

    plan_utils.grant_plan_to_pet(db, pet, make_plan(STANDARD_PRICE), member)

    assert pet.plan_activated_at is not None


def test_granting_creates_the_plans_sessions(db, make_member, make_plan, make_pet, make_service_type):
    member = make_member()
    pet = make_pet(member)
    plan = make_plan(STANDARD_PRICE)
    _add_plan_service(db, plan, make_service_type("Vaccines"), sessions=3)

    plan_utils.grant_plan_to_pet(db, pet, plan, member)

    assert _pet_services(db, pet) == {"Vaccines": 3}


def test_a_category_granting_no_sessions_is_skipped(db, make_member, make_plan, make_pet, make_service_type):
    """Reimbursement-only categories sit on a plan with zero sessions; they must
    not create an empty benefit row."""
    member = make_member()
    pet = make_pet(member)
    plan = make_plan(STANDARD_PRICE)
    _add_plan_service(db, plan, make_service_type("Vaccines"), sessions=2)
    _add_plan_service(db, plan, make_service_type("Preventive Wellness"), sessions=0)

    plan_utils.grant_plan_to_pet(db, pet, plan, member)

    assert _pet_services(db, pet) == {"Vaccines": 2}


def test_regranting_replaces_rather_than_stacks(db, make_member, make_plan, make_pet, make_service_type):
    """The invariant: a renewal resets to the plan's sessions, it does not add."""
    member = make_member()
    pet = make_pet(member)
    plan = make_plan(STANDARD_PRICE)
    _add_plan_service(db, plan, make_service_type("Vaccines"), sessions=3)

    plan_utils.grant_plan_to_pet(db, pet, plan, member)
    plan_utils.grant_plan_to_pet(db, pet, plan, member)

    assert _pet_services(db, pet) == {"Vaccines": 3}


def test_regranting_forfeits_unused_sessions(db, make_member, make_plan, make_pet, make_service_type):
    """"No more, no less" than the new plan — last year's leftovers don't carry."""
    member = make_member()
    pet = make_pet(member)
    plan = make_plan(STANDARD_PRICE)
    _add_plan_service(db, plan, make_service_type("Vaccines"), sessions=3)
    plan_utils.grant_plan_to_pet(db, pet, plan, member)
    db.flush()

    plan_utils.grant_plan_to_pet(db, pet, plan, member)
    db.flush()
    used = db.query(models.PetService).filter(models.PetService.pet_id == pet.id).all()

    assert [row.used_sessions for row in used] == [0]


def test_upgrading_replaces_the_old_plans_categories(db, make_member, make_plan, make_pet, make_service_type):
    """Categories only the old plan had must disappear, not linger."""
    member = make_member()
    pet = make_pet(member)
    standard = make_plan(STANDARD_PRICE)
    premium = make_plan(PREMIUM_PRICE)
    _add_plan_service(db, standard, make_service_type("Vaccines"), sessions=2)
    _add_plan_service(db, premium, make_service_type("Full Grooming"), sessions=4)

    plan_utils.grant_plan_to_pet(db, pet, standard, member)
    plan_utils.grant_plan_to_pet(db, pet, premium, member)

    assert _pet_services(db, pet) == {"Full Grooming": 4}


def test_sessions_expire_a_year_out(db, make_member, make_plan, make_pet, make_service_type):
    member = make_member()
    pet = make_pet(member)
    plan = make_plan(STANDARD_PRICE)
    _add_plan_service(db, plan, make_service_type("Vaccines"), sessions=1)

    plan_utils.grant_plan_to_pet(db, pet, plan, member)
    db.flush()
    row = db.query(models.PetService).filter(models.PetService.pet_id == pet.id).first()

    # SQLite drops tzinfo on the way back out; Postgres returns it. Normalise the
    # same way the production code does in plan_term_utils._aware.
    expires_at = row.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    expected = datetime.now(timezone.utc) + timedelta(days=PLAN_TERM_DAYS)

    assert abs((expires_at - expected).total_seconds()) < 60


def test_founding_member_gets_the_bonus_sessions(db, make_member, make_plan, make_pet, make_service_type):
    member = make_member(is_founding=True)
    pet = make_pet(member)
    plan = make_plan(STANDARD_PRICE)
    make_service_type("Grooming")
    make_service_type("General Consultation")

    plan_utils.grant_plan_to_pet(db, pet, plan, member)

    assert _pet_services(db, pet) == {"Grooming": 1, "General Consultation": 1}


def test_founding_bonus_tops_up_a_category_the_plan_already_grants(
    db, make_member, make_plan, make_pet, make_service_type
):
    """It must add to the existing row, not create a second one — a duplicate
    would violate uq_pet_service and double the benefit."""
    member = make_member(is_founding=True)
    pet = make_pet(member)
    plan = make_plan(STANDARD_PRICE)
    grooming = make_service_type("Grooming")
    _add_plan_service(db, plan, grooming, sessions=2)

    plan_utils.grant_plan_to_pet(db, pet, plan, member)

    assert _pet_services(db, pet)["Grooming"] == 3


def test_founding_bonus_creates_exactly_one_row_per_category(
    db, make_member, make_plan, make_pet, make_service_type
):
    member = make_member(is_founding=True)
    pet = make_pet(member)
    plan = make_plan(STANDARD_PRICE)
    _add_plan_service(db, plan, make_service_type("Grooming"), sessions=2)

    plan_utils.grant_plan_to_pet(db, pet, plan, member)
    db.flush()
    rows = db.query(models.PetService).filter(models.PetService.pet_id == pet.id).all()

    assert len(rows) == 1


def test_ordinary_member_gets_no_bonus(db, make_member, make_plan, make_pet, make_service_type):
    member = make_member(is_founding=False)
    pet = make_pet(member)
    plan = make_plan(STANDARD_PRICE)
    make_service_type("Grooming")

    plan_utils.grant_plan_to_pet(db, pet, plan, member)

    assert _pet_services(db, pet) == {}


def test_a_missing_bonus_category_is_skipped(db, make_member, make_plan, make_pet):
    """A database without the seeded categories must not break a grant."""
    member = make_member(is_founding=True)
    pet = make_pet(member)

    plan_utils.grant_plan_to_pet(db, pet, make_plan(STANDARD_PRICE), member)

    assert _pet_services(db, pet) == {}


def test_premium_tier_is_remembered_for_the_discount(db, make_member, make_plan, make_pet):
    member = make_member()
    pet = make_pet(member)

    plan_utils.grant_plan_to_pet(db, pet, make_plan(PREMIUM_PRICE, name="Premium"), member)

    assert member.previous_plan_tier == "Premium"


def test_standard_tier_is_not_recorded_as_a_previous_tier(db, make_member, make_plan, make_pet):
    member = make_member()
    pet = make_pet(member)

    plan_utils.grant_plan_to_pet(db, pet, make_plan(STANDARD_PRICE, name="Standard"), member)

    assert member.previous_plan_tier is None


def test_downgrading_keeps_the_earlier_premium_tier(db, make_member, make_plan, make_pet):
    """Eligibility is "has ever held", so a later Standard must not erase it."""
    member = make_member()
    pet = make_pet(member)
    plan_utils.grant_plan_to_pet(db, pet, make_plan(PREMIUM_PRICE, name="Premium"), member)

    plan_utils.grant_plan_to_pet(db, pet, make_plan(STANDARD_PRICE, name="Standard"), member)

    assert member.previous_plan_tier == "Premium"


def test_member_level_grant_tops_up_instead_of_replacing(
    db, make_member, make_plan, make_service_type
):
    """The deliberate asymmetry with the per-pet grant: this one accumulates.
    It backs the legacy member-level flow, not the current per-pet one.

    The flush between grants stands in for the commit a real second purchase
    would make. Without it this function adds a duplicate row rather than
    topping up, because it has no equivalent of the explicit flush that
    grant_plan_to_pet does before its founding-bonus loop — and unlike
    pet_services, member_services has no unique constraint to catch it.
    """
    member = make_member()
    plan = make_plan(STANDARD_PRICE)
    _add_plan_service(db, plan, make_service_type("Vaccines"), sessions=3)

    plan_utils.grant_plan_to_member(db, member, plan)
    db.flush()
    plan_utils.grant_plan_to_member(db, member, plan)
    db.flush()
    row = db.query(models.MemberService).filter(models.MemberService.member_id == member.id).first()

    assert row.total_sessions == 6


def _member_services(db, member) -> dict[str, int]:
    db.flush()
    rows = (
        db.query(models.MemberService, models.ServiceType)
        .join(models.ServiceType, models.MemberService.service_type_id == models.ServiceType.id)
        .filter(models.MemberService.member_id == member.id)
        .all()
    )
    return {service_type.name: service.total_sessions for service, service_type in rows}


def test_member_level_grant_records_the_plan(db, make_member, make_plan):
    member = make_member()

    plan_utils.grant_plan_to_member(db, member, make_plan(STANDARD_PRICE, name="Standard"))

    assert (member.plan_id, member.plan_type) == (member.plan_id, "Standard")


def test_member_level_grant_skips_zero_session_categories(
    db, make_member, make_plan, make_service_type
):
    member = make_member()
    plan = make_plan(STANDARD_PRICE)
    _add_plan_service(db, plan, make_service_type("Vaccines"), sessions=2)
    _add_plan_service(db, plan, make_service_type("Preventive Wellness"), sessions=0)

    plan_utils.grant_plan_to_member(db, member, plan)

    assert _member_services(db, member) == {"Vaccines": 2}


def test_member_level_grant_gives_founding_members_the_bonus(
    db, make_member, make_plan, make_service_type
):
    member = make_member(is_founding=True)
    make_service_type("Grooming")
    make_service_type("General Consultation")

    plan_utils.grant_plan_to_member(db, member, make_plan(STANDARD_PRICE))

    assert _member_services(db, member) == {"Grooming": 1, "General Consultation": 1}


def test_member_level_founding_bonus_tops_up_an_existing_category(
    db, make_member, make_plan, make_service_type
):
    member = make_member(is_founding=True)
    plan = make_plan(STANDARD_PRICE)
    _add_plan_service(db, plan, make_service_type("Grooming"), sessions=2)

    plan_utils.grant_plan_to_member(db, member, plan)

    assert _member_services(db, member)["Grooming"] == 3


def test_member_level_founding_bonus_creates_no_duplicate_row(
    db, make_member, make_plan, make_service_type
):
    """The bug this pins: without a flush before the bonus loop, the lookup
    missed the pending insert and added a second row for the same category.
    member_services has no unique constraint, so nothing would have stopped it —
    the identical fault on the pet side needed a migration to clean up."""
    member = make_member(is_founding=True)
    plan = make_plan(STANDARD_PRICE)
    _add_plan_service(db, plan, make_service_type("Grooming"), sessions=2)

    plan_utils.grant_plan_to_member(db, member, plan)
    db.flush()
    rows = db.query(models.MemberService).filter(models.MemberService.member_id == member.id).all()

    assert len(rows) == 1


def test_member_level_grant_skips_a_missing_bonus_category(db, make_member, make_plan):
    member = make_member(is_founding=True)

    plan_utils.grant_plan_to_member(db, member, make_plan(STANDARD_PRICE))

    assert _member_services(db, member) == {}
