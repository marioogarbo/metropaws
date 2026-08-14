"""Shared test fixtures.

The environment is pinned HERE, before any project module is imported, because
config.py never overwrites a variable that is already set. That makes the suite
hermetic: it runs against an in-memory SQLite database and cannot reach the dev
or production Supabase projects even if an env file is present.
"""
import os

os.environ["APP_ENV"] = "dev"
os.environ["DATABASE_URL"] = "sqlite://"
os.environ["SECRET_KEY"] = "test-only-secret"
# Pinned so the app under test has a known CORS state rather than inheriting
# whatever .env.dev happens to list today.
os.environ["ALLOWED_ORIGINS"] = ""
os.environ["ALLOWED_ORIGIN_REGEX"] = ""

from datetime import date, datetime, timedelta, timezone  # noqa: E402
from itertools import count  # noqa: E402

import pytest  # noqa: E402
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

import models  # noqa: E402

_unique = count(1)


@pytest.fixture
def db():
    """A session on a fresh in-memory database, one per test (F.I.R.S.T.)."""
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    models.Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine, autoflush=False)()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture
def make_plan(db):
    def _make_plan(price: int, **overrides) -> models.Plan:
        plan = models.Plan(
            name=overrides.pop("name", f"Plan {next(_unique)}"),
            price=price,
            features=[],
            **overrides,
        )
        db.add(plan)
        db.flush()
        return plan

    return _make_plan


@pytest.fixture
def make_member(db):
    def _make_member(**overrides) -> models.Member:
        user = models.User(
            email=f"member{next(_unique)}@example.com",
            password_hash="not-a-real-hash",
        )
        db.add(user)
        db.flush()
        member = models.Member(
            user_id=user.id,
            first_name="Test",
            last_name="Member",
            **overrides,
        )
        db.add(member)
        db.flush()
        return member

    return _make_member


@pytest.fixture
def make_pet(db):
    def _make_pet(member: models.Member, **overrides) -> models.Pet:
        pet = models.Pet(
            member_id=member.id,
            name=overrides.pop("name", f"Pet {next(_unique)}"),
            breed="Aspin",
            birth_month=1,
            birth_year=2020,
            weight_kg=10.0,
            **overrides,
        )
        db.add(pet)
        db.flush()
        return pet

    return _make_pet


@pytest.fixture
def make_service_type(db):
    def _make_service_type(name: str) -> models.ServiceType:
        service_type = models.ServiceType(name=name)
        db.add(service_type)
        db.flush()
        return service_type

    return _make_service_type


@pytest.fixture
def make_claim(db):
    def _make_claim(
        pet: models.Pet,
        service_type: models.ServiceType,
        status: models.ReimbursementStatus,
        claimed_centavos: int,
        approved_centavos: int | None = None,
        service_date: date | None = None,
    ) -> models.Reimbursement:
        claim = models.Reimbursement(
            member_id=pet.member_id,
            pet_id=pet.id,
            service_type_id=service_type.id,
            provider_name="Test Vet",
            service_date=service_date or date(2026, 6, 1),
            claimed_amount_centavos=claimed_centavos,
            approved_amount_centavos=approved_centavos,
            receipt_url="https://example.test/receipt.pdf",
            status=status,
        )
        db.add(claim)
        db.flush()
        return claim

    return _make_claim


@pytest.fixture
def set_app_setting(db):
    def _set_app_setting(key: str, value: str) -> None:
        db.add(models.AppSetting(key=key, value=value))
        db.flush()

    return _set_app_setting


@pytest.fixture
def days_ago():
    """A timezone-aware datetime N days in the past."""

    def _days_ago(days: int) -> datetime:
        return datetime.now(timezone.utc) - timedelta(days=days)

    return _days_ago
