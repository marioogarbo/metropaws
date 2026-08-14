"""The app boots, and its URL surface is exactly what it was.

routes_snapshot.json pins every (method, path) the API exposes. Moving handlers
between modules — splitting routers/admin.py, for instance — must not change
that surface, and any deliberate addition has to be recorded by regenerating
the snapshot:

    python -m tests.generate_routes_snapshot

The mobile app and the website both call these paths directly; a silently
renamed route is a production outage, not a test failure.
"""
import json
from pathlib import Path

from fastapi.testclient import TestClient

from app import main

SNAPSHOT_PATH = Path(__file__).parent / "routes_snapshot.json"


def route_table(app) -> list[str]:
    """Every callable endpoint as "METHOD /path", sorted. HEAD is dropped —
    Starlette adds it automatically alongside GET."""
    return sorted(
        f"{method} {route.path}"
        for route in app.routes
        for method in (getattr(route, "methods", None) or ())
        if method != "HEAD"
    )


def test_app_exposes_the_expected_routes():
    expected = json.loads(SNAPSHOT_PATH.read_text(encoding="utf-8"))

    assert route_table(main.app) == expected


def test_root_reports_the_api_is_live():
    with TestClient(main.app) as client:
        assert client.get("/").status_code == 200


def test_health_check_passes():
    """Render's health check hits this — if it fails, deploys roll back."""
    with TestClient(main.app) as client:
        assert client.get("/health").json() == {"status": "ok"}
