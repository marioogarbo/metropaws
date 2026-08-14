"""Who is allowed through each route — auth.require_admin / require_member.

Nothing exercised these before, which meant deleting a guard from a handler
broke no test. These walk the real route table instead of naming endpoints, so
a route added tomorrow is covered the day it appears.

401 vs 403 is the distinction under test: 401 is "you are nobody", 403 is "you
are somebody, but not the right somebody". A route returning 200 to either is a
hole.
"""
import re

import pytest
from fastapi.testclient import TestClient

from app import auth as auth_utils
from app import main
from app import models
from app.database import get_db
from tests.api_surface import DOCS_ROUTES, route_table, routes_under

PARAM = re.compile(r"\{[^}]+\}")


@pytest.fixture
def client(db):
    """The real app, talking to the test database."""
    main.app.dependency_overrides[get_db] = lambda: db
    with TestClient(main.app) as test_client:
        yield test_client
    main.app.dependency_overrides.clear()


def _user(db, role: models.UserRole) -> models.User:
    user = models.User(email=f"{role.value}@example.test", password_hash="x", role=role)
    db.add(user)
    db.flush()
    return user


def _token(user: models.User) -> str:
    return auth_utils.create_access_token({"sub": user.id, "role": user.role})


def _auth(user: models.User) -> dict:
    return {"Authorization": f"Bearer {_token(user)}"}


ADMIN_ROUTES = [
    (method, PARAM.sub("sample-value", path))
    for method, path in routes_under(main.app, "/admin")
]


def test_there_are_admin_routes_to_guard():
    """Guards the guard: if the route scan silently returned nothing, every
    test below would pass without asserting anything."""
    assert len(ADMIN_ROUTES) > 30


@pytest.mark.parametrize("method,path", ADMIN_ROUTES, ids=lambda v: str(v))
def test_admin_route_rejects_anonymous(client, method, path):
    response = client.request(method, path)

    assert response.status_code == 401


@pytest.mark.parametrize("method,path", ADMIN_ROUTES, ids=lambda v: str(v))
def test_admin_route_rejects_a_member(client, db, method, path):
    member = _user(db, models.UserRole.member)

    response = client.request(method, path, headers=_auth(member))

    assert response.status_code == 403


def test_admin_route_rejects_a_clinic_login(client, db):
    """Clinic accounts are real logins with no business in the admin API."""
    clinic = _user(db, models.UserRole.clinic)

    response = client.get("/admin/members", headers=_auth(clinic))

    assert response.status_code == 403


def test_admin_token_gets_past_the_guard(client, db):
    """The other side of it: a real admin must actually be let through."""
    admin = _user(db, models.UserRole.admin)

    response = client.get("/admin/members", headers=_auth(admin))

    assert response.status_code == 200


def test_a_deactivated_admin_is_refused(client, db):
    """is_active is checked on every request, not just at login."""
    admin = _user(db, models.UserRole.admin)
    headers = _auth(admin)
    admin.is_active = False
    db.flush()

    response = client.get("/admin/members", headers=headers)

    assert response.status_code == 401


def test_a_token_for_a_deleted_user_is_refused(client, db):
    admin = _user(db, models.UserRole.admin)
    headers = _auth(admin)
    db.delete(admin)
    db.flush()

    response = client.get("/admin/members", headers=headers)

    assert response.status_code == 401


def test_a_garbage_token_is_refused(client):
    response = client.get("/admin/members", headers={"Authorization": "Bearer not-a-jwt"})

    assert response.status_code == 401


def test_a_token_signed_with_another_key_is_refused(client, db):
    """The reason SECRET_KEY is worth rotating: a token signed with a different
    key must not be accepted."""
    from jose import jwt

    admin = _user(db, models.UserRole.admin)
    forged = jwt.encode({"sub": admin.id, "role": "admin"}, "some-other-secret", algorithm="HS256")

    response = client.get("/admin/members", headers={"Authorization": f"Bearer {forged}"})

    assert response.status_code == 401


def test_member_route_rejects_anonymous(client):
    response = client.get("/members/me")

    assert response.status_code == 401


def test_public_routes_stay_public(client):
    """The guards must not have crept onto the endpoints that need to be open."""
    assert client.get("/health").status_code == 200
    assert client.get("/").status_code == 200


# Every route reachable without a token. Each one is deliberate:
#   /auth/*                     you cannot authenticate to authenticate
#   /payments/return/*, webhook PayMongo calls these; the webhook is signature-verified
#   /plans /faqs /promos /directory /paw-points/rewards   public content
#   /settings/*                 flags the app and website read before sign-in
#   /members/clinics, /members/reimbursement-providers    public lists, no payout details
#   /docs /redoc /openapi.json  FastAPI's own docs
#   POST /members/me/plan       deprecated, answers 410 to everyone
#
# Adding to this list should be a decision, not an accident.
PUBLIC_SURFACE = {
    "GET /",
    "GET /auth/check-email",
    "GET /directory",
    "GET /docs",
    "GET /docs/oauth2-redirect",
    "GET /faqs",
    "GET /health",
    "GET /members/clinics",
    "GET /members/reimbursement-providers",
    "GET /openapi.json",
    "GET /paw-points/rewards",
    "GET /payments/return/failed",
    "GET /payments/return/success",
    "GET /plans",
    "GET /promos",
    "GET /redoc",
    "GET /settings/founding-50",
    "GET /settings/mobile-config",
    "GET /settings/pack-discount",
    "GET /settings/payments-enabled",
    "POST /auth/forgot-password",
    "POST /auth/login",
    "POST /auth/register",
    "POST /auth/reset-password",
    "POST /founding-reservations",
    "POST /members/me/plan",
    "POST /payments/webhook",
}


def test_the_unauthenticated_surface_is_exactly_what_we_intend(client):
    """Walks every route anonymously. A new endpoint that forgets its guard
    shows up here as an addition, which is the failure worth catching — the
    per-route tests above only cover /admin."""
    reachable = set()
    for entry in route_table(main.app) + sorted(DOCS_ROUTES):
        method, path = entry.split(" ", 1)
        response = client.request(method, PARAM.sub("sample-value", path))
        # Anything other than 401 answered without credentials, whatever it
        # then said about the request itself.
        if response.status_code != 401:
            reachable.add(entry)

    assert reachable == PUBLIC_SURFACE
