"""Editing a plan's benefit configuration — routers.admin.plans._apply_service_caps.

This is money configuration: the reimbursement cap and session count an admin
sets here decide what every member on that plan can claim. It is append-only
audited, so the tests check the audit trail as closely as the values — an
unrecorded change to a wallet is the part you cannot reconstruct later.
"""
import pytest
from fastapi import HTTPException

import models
from routers.admin.plans import _apply_service_caps

STANDARD_PRICE = 2999
CAP = 150_000
HIGHER_CAP = 300_000


@pytest.fixture
def admin(db):
    user = models.User(email="admin@example.test", password_hash="x", role=models.UserRole.admin)
    db.add(user)
    db.flush()
    return user


@pytest.fixture
def plan_with(db, make_plan):
    """A plan carrying the given categories, with plan_services loaded."""

    def _plan_with(**sessions_and_caps) -> tuple[models.Plan, dict[str, models.ServiceType]]:
        plan = make_plan(STANDARD_PRICE)
        types = {}
        for name, (sessions, cap) in sessions_and_caps.items():
            service_type = models.ServiceType(name=name)
            db.add(service_type)
            db.flush()
            db.add(
                models.PlanService(
                    plan_id=plan.id,
                    service_type_id=service_type.id,
                    sessions=sessions,
                    reimbursement_cap_centavos=cap,
                )
            )
            types[name] = service_type
        db.flush()
        db.refresh(plan)
        return plan, types

    return _plan_with


def _events(db, plan) -> list[models.PlanChangeEvent]:
    db.flush()
    return db.query(models.PlanChangeEvent).filter(models.PlanChangeEvent.plan_id == plan.id).all()


def _plan_services(db, plan) -> list[models.PlanService]:
    db.flush()
    return db.query(models.PlanService).filter(models.PlanService.plan_id == plan.id).all()


def test_adding_a_category_creates_the_row(db, admin, plan_with, make_service_type):
    plan, _types = plan_with()
    grooming = make_service_type("Grooming")

    _apply_service_caps(
        db, plan, [{"service_type_id": grooming.id, "reimbursement_cap_centavos": CAP, "sessions": 2}], admin
    )
    rows = _plan_services(db, plan)

    assert [(row.service_type_id, row.sessions, row.reimbursement_cap_centavos) for row in rows] == [
        (grooming.id, 2, CAP)
    ]


def test_adding_a_category_without_sessions_grants_none(db, admin, plan_with, make_service_type):
    """A reimbursement-only category: claimable, but grants no visits."""
    plan, _types = plan_with()
    emergency = make_service_type("Emergency")

    _apply_service_caps(
        db, plan, [{"service_type_id": emergency.id, "reimbursement_cap_centavos": CAP}], admin
    )

    assert _plan_services(db, plan)[0].sessions == 0


def test_adding_a_category_is_audited(db, admin, plan_with, make_service_type):
    plan, _types = plan_with()
    grooming = make_service_type("Grooming")

    _apply_service_caps(
        db, plan, [{"service_type_id": grooming.id, "reimbursement_cap_centavos": CAP, "sessions": 2}], admin
    )
    event = _events(db, plan)[0]

    assert (event.field, event.from_value, event.to_value) == (
        "category_added",
        None,
        f"sessions=2;cap={CAP}",
    )


def test_an_unknown_category_is_rejected(db, admin, plan_with):
    """A stale id from the admin UI must not create an orphan benefit row."""
    plan, _types = plan_with()

    with pytest.raises(HTTPException) as raised:
        _apply_service_caps(
            db, plan, [{"service_type_id": "no-such-id", "reimbursement_cap_centavos": CAP}], admin
        )

    assert raised.value.status_code == 422


def test_raising_a_cap_updates_it(db, admin, plan_with):
    plan, types = plan_with(Grooming=(2, CAP))

    _apply_service_caps(
        db, plan, [{"service_type_id": types["Grooming"].id, "reimbursement_cap_centavos": HIGHER_CAP}], admin
    )

    assert _plan_services(db, plan)[0].reimbursement_cap_centavos == HIGHER_CAP


def test_a_cap_change_records_both_values(db, admin, plan_with):
    """The old value is the part you can't recover from the row afterwards."""
    plan, types = plan_with(Grooming=(2, CAP))

    _apply_service_caps(
        db, plan, [{"service_type_id": types["Grooming"].id, "reimbursement_cap_centavos": HIGHER_CAP}], admin
    )
    event = _events(db, plan)[0]

    assert (event.field, event.from_value, event.to_value) == (
        "reimbursement_cap_centavos",
        str(CAP),
        str(HIGHER_CAP),
    )


def test_a_session_change_is_audited_separately(db, admin, plan_with):
    plan, types = plan_with(Grooming=(2, CAP))

    _apply_service_caps(
        db,
        plan,
        [{"service_type_id": types["Grooming"].id, "reimbursement_cap_centavos": CAP, "sessions": 4}],
        admin,
    )
    event = _events(db, plan)[0]

    assert (event.field, event.from_value, event.to_value) == ("sessions", "2", "4")


def test_changing_both_records_two_events(db, admin, plan_with):
    plan, types = plan_with(Grooming=(2, CAP))

    _apply_service_caps(
        db,
        plan,
        [{"service_type_id": types["Grooming"].id, "reimbursement_cap_centavos": HIGHER_CAP, "sessions": 4}],
        admin,
    )

    assert sorted(event.field for event in _events(db, plan)) == [
        "reimbursement_cap_centavos",
        "sessions",
    ]


def test_resubmitting_the_same_values_records_nothing(db, admin, plan_with):
    """Saving the Plans page without editing must not fill the audit trail."""
    plan, types = plan_with(Grooming=(2, CAP))

    _apply_service_caps(
        db,
        plan,
        [{"service_type_id": types["Grooming"].id, "reimbursement_cap_centavos": CAP, "sessions": 2}],
        admin,
    )

    assert _events(db, plan) == []


def test_omitting_sessions_leaves_them_alone(db, admin, plan_with):
    """A payload that only carries a cap must not silently zero the sessions."""
    plan, types = plan_with(Grooming=(2, CAP))

    _apply_service_caps(
        db, plan, [{"service_type_id": types["Grooming"].id, "reimbursement_cap_centavos": HIGHER_CAP}], admin
    )

    assert _plan_services(db, plan)[0].sessions == 2


def test_sessions_can_be_set_to_zero(db, admin, plan_with):
    """Boundary: 0 is a real value, and must not be read as "not supplied"."""
    plan, types = plan_with(Grooming=(2, CAP))

    _apply_service_caps(
        db,
        plan,
        [{"service_type_id": types["Grooming"].id, "reimbursement_cap_centavos": CAP, "sessions": 0}],
        admin,
    )

    assert _plan_services(db, plan)[0].sessions == 0


def test_the_editing_admin_is_recorded(db, admin, plan_with):
    plan, types = plan_with(Grooming=(2, CAP))

    _apply_service_caps(
        db, plan, [{"service_type_id": types["Grooming"].id, "reimbursement_cap_centavos": HIGHER_CAP}], admin
    )

    assert _events(db, plan)[0].actor_user_id == admin.id


def test_several_categories_are_applied_in_one_call(db, admin, plan_with):
    plan, types = plan_with(Grooming=(2, CAP), Vaccines=(1, CAP))

    _apply_service_caps(
        db,
        plan,
        [
            {"service_type_id": types["Grooming"].id, "reimbursement_cap_centavos": HIGHER_CAP},
            {"service_type_id": types["Vaccines"].id, "reimbursement_cap_centavos": HIGHER_CAP},
        ],
        admin,
    )
    caps = {row.service_type_id: row.reimbursement_cap_centavos for row in _plan_services(db, plan)}

    assert caps == {types["Grooming"].id: HIGHER_CAP, types["Vaccines"].id: HIGHER_CAP}


def test_a_category_left_out_of_the_payload_is_untouched(db, admin, plan_with):
    """Editing one category must not disturb the rest of the plan."""
    plan, types = plan_with(Grooming=(2, CAP), Vaccines=(1, CAP))

    _apply_service_caps(
        db, plan, [{"service_type_id": types["Grooming"].id, "reimbursement_cap_centavos": HIGHER_CAP}], admin
    )
    vaccines = next(
        row for row in _plan_services(db, plan) if row.service_type_id == types["Vaccines"].id
    )

    assert (vaccines.sessions, vaccines.reimbursement_cap_centavos) == (1, CAP)
