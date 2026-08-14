"""Seeding a fresh database — seed.py.

Two properties matter. It must do nothing on import, because it creates tables
and an admin account against whatever APP_ENV resolves to. And every step must
be idempotent, because topping a database up after adding a new default means
running the whole thing again over live data.
"""
import ast
from pathlib import Path

import pytest

import models
import seed

SEED_SOURCE = Path(seed.__file__)
INERT = (ast.Import, ast.ImportFrom, ast.FunctionDef, ast.ClassDef, ast.Assign, ast.AnnAssign)


@pytest.fixture(autouse=True)
def seed_credentials(monkeypatch):
    monkeypatch.setenv("SEED_ADMIN_PASSWORD", "test-only-password")
    monkeypatch.delenv("SEED_CLINIC_PASSWORD", raising=False)
    monkeypatch.delenv("SEED_ADMIN_EMAIL", raising=False)


def _run_all(db) -> None:
    """Deliberately the real entry point, not a copy of its loop — an earlier
    version of this helper skipped the commit between steps and "failed" on
    correct code."""
    seed.run_all(db)


def _count(db, model) -> int:
    db.flush()
    return db.query(model).count()


def test_importing_seed_executes_nothing():
    """It creates tables and an admin user — importing must not do that."""
    tree = ast.parse(SEED_SOURCE.read_text(encoding="utf-8"))
    executable = [
        node
        for node in tree.body
        if not isinstance(node, INERT)
        and not (isinstance(node, ast.Expr) and isinstance(node.value, ast.Constant))
        and not (
            isinstance(node, ast.If)
            and isinstance(node.test, ast.Compare)
            and isinstance(node.test.left, ast.Name)
            and node.test.left.id == "__name__"
        )
    ]

    assert executable == []


def test_every_seeder_is_registered():
    defined = {
        node.name
        for node in ast.parse(SEED_SOURCE.read_text(encoding="utf-8")).body
        if isinstance(node, ast.FunctionDef) and node.name.startswith("seed_")
    }
    registered = {seeder.__name__ for seeder in seed.SEEDERS}

    assert defined == registered


def test_service_types_are_created(db):
    _run_all(db)

    assert _count(db, models.ServiceType) == len(seed.SERVICE_TYPES)


def test_the_three_plans_are_created(db):
    _run_all(db)
    names = {plan.name for plan in db.query(models.Plan).all()}

    assert names == {"Standard", "Deluxe", "Premium"}


def test_plans_get_their_session_and_cap_rows(db):
    _run_all(db)
    expected = sum(len(rows) for rows in seed.PLAN_SERVICES.values())

    assert _count(db, models.PlanService) == expected


def test_app_settings_start_at_their_launch_defaults(db):
    _run_all(db)
    settings = {row.key: row.value for row in db.query(models.AppSetting).all()}

    assert settings == dict(seed.DEFAULT_APP_SETTINGS)


def test_an_admin_account_is_created(db):
    _run_all(db)
    admin = db.query(models.User).filter(models.User.role == models.UserRole.admin).one()

    assert admin.email == seed.DEFAULT_ADMIN_EMAIL


def test_the_paw_points_catalogue_is_created(db):
    """Seven rewards from the Member Manual, previously only reachable by
    pasting migrations/add_paw_points.sql into the Supabase SQL editor."""
    _run_all(db)

    assert _count(db, models.PawPointsReward) == len(seed.PAW_POINTS_REWARDS)


def test_faqs_are_published(db):
    _run_all(db)

    assert _count(db, models.FAQ) == len(seed.FAQS)


def test_sample_clinics_are_skipped_without_a_password(db):
    """Production must never get logins whose password lives in this repo."""
    _run_all(db)

    assert _count(db, models.ClinicPartner) == 0


def test_sample_clinics_are_created_when_asked_for(db, monkeypatch):
    monkeypatch.setenv("SEED_CLINIC_PASSWORD", "test-only-password")

    _run_all(db)

    assert _count(db, models.ClinicPartner) == len(seed.CLINICS)


SEEDED_MODELS = (
    models.ServiceType,
    models.Plan,
    models.PlanService,
    models.AppSetting,
    models.PawPointsReward,
    models.FAQ,
    models.User,
)


def test_running_twice_creates_no_duplicates(db):
    """The property the old hand-run SQL didn't have: its rewards used
    gen_random_uuid() ids, so ON CONFLICT never matched and a second run
    inserted all seven again.

    One test rather than one per model: seeding hashes a password with bcrypt,
    which is deliberately slow, so re-seeding once beats re-seeding seven times.
    """
    _run_all(db)
    first = {model.__name__: _count(db, model) for model in SEEDED_MODELS}

    _run_all(db)

    assert {model.__name__: _count(db, model) for model in SEEDED_MODELS} == first


def test_an_edited_setting_is_not_reset(db):
    """Re-seeding tops a database up; it must not undo an admin's change."""
    _run_all(db)
    payments = db.query(models.AppSetting).filter(models.AppSetting.key == "payments_enabled").one()
    payments.value = "false"
    db.flush()

    _run_all(db)

    assert payments.value == "false"
