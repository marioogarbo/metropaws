"""The app boots, and its URL surface is exactly what it was.

routes_snapshot.json pins every documented (method, path) the API exposes.
Moving handlers between modules — splitting a router, introducing app/ — must
not change that surface, and any deliberate addition has to be recorded by
regenerating the snapshot:

    python -m tests.generate_routes_snapshot

The mobile app and the website both call these paths directly; a silently
renamed route is a production outage, not a test failure.
"""
import json
from pathlib import Path

from fastapi.testclient import TestClient

from app import main
from tests.api_surface import route_table

SNAPSHOT_PATH = Path(__file__).parent / "routes_snapshot.json"


def test_app_exposes_the_expected_routes():
    expected = json.loads(SNAPSHOT_PATH.read_text(encoding="utf-8"))

    assert route_table(main.app) == expected


def test_the_snapshot_covers_the_whole_api():
    """Guards the guard. This table used to be read from app.routes, which
    quietly returned almost nothing after a FastAPI upgrade — an empty
    comparison against an empty snapshot would have passed."""
    assert len(route_table(main.app)) > 100


def test_root_reports_the_api_is_live():
    with TestClient(main.app) as client:
        assert client.get("/").status_code == 200


def test_health_check_passes():
    """Render's health check hits this — if it fails, deploys roll back."""
    with TestClient(main.app) as client:
        assert client.get("/health").json() == {"status": "ok"}
