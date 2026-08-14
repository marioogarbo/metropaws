"""Datetime helpers shared by the money paths."""
from datetime import datetime, timezone


def aware(value: datetime) -> datetime:
    """Return ``value`` with a timezone, assuming UTC when it has none.

    Postgres hands back tz-aware datetimes, so in production this is a no-op.
    It exists because comparing an aware datetime to a naive one raises, and
    every caller here is on a path that decides money or eligibility — a driver
    or backend quirk must not be able to crash those.
    """
    return value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
