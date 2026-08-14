"""Regenerate tests/routes_snapshot.json from the app as it stands.

Run this ONLY when the URL surface changed on purpose, and read the diff before
committing it — the snapshot is what stops a refactor from quietly moving or
dropping an endpoint the mobile app depends on.

    python -m tests.generate_routes_snapshot
"""
import json

from app import main
from tests.api_surface import route_table
from tests.test_app_routes import SNAPSHOT_PATH

routes = route_table(main.app)
SNAPSHOT_PATH.write_text(json.dumps(routes, indent=2) + "\n", encoding="utf-8")
print(f"Wrote {len(routes)} routes to {SNAPSHOT_PATH}")
