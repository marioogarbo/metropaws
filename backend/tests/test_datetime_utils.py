"""The timezone guard the money paths share — datetime_utils.aware."""
from datetime import datetime, timedelta, timezone

from app.datetime_utils import aware

NAIVE = datetime(2026, 8, 14, 3, 21)
UTC = timezone.utc


def test_a_naive_datetime_is_assumed_to_be_utc():
    assert aware(NAIVE) == NAIVE.replace(tzinfo=UTC)


def test_an_aware_datetime_is_returned_unchanged():
    already = NAIVE.replace(tzinfo=UTC)

    assert aware(already) is already


def test_a_non_utc_offset_is_preserved():
    """Assume UTC only when there is nothing to go on — never overwrite."""
    manila = datetime(2026, 8, 14, 11, 21, tzinfo=timezone(timedelta(hours=8)))

    assert aware(manila).utcoffset() == timedelta(hours=8)


def test_the_result_can_always_be_compared():
    """The whole reason this exists: mixing the two forms raises TypeError."""
    assert aware(NAIVE) < aware(NAIVE.replace(tzinfo=UTC) + timedelta(days=1))
