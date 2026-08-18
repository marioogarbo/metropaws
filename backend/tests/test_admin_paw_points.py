"""Admin PawPoints reporting — the per-member balances and programme totals.

Every figure is a SUM over the append-only ledger, so the cases here pin the two
things that can silently go wrong in that arithmetic: a redemption must debit the
balance without touching lifetime earned, and a member who has earned nothing
must still appear (at zero) rather than vanish from the list.
"""
from app import models
from app.routers.admin.paw_points import (
    list_member_balances,
    member_paw_points_detail,
    paw_points_summary,
)

ACTIVATION = "membership_activation"
REDEMPTION = "admin_manual_award"


def _award(db, member, points: int, activity: str = ACTIVATION) -> None:
    db.add(
        models.PawPointsTransaction(
            member_id=member.id,
            points=points,
            activity_type=activity,
        )
    )
    db.flush()


def _summary(db):
    return paw_points_summary(current_user=None, db=db)


def _balances(db, search=None):
    return list_member_balances(
        search=search, skip=0, limit=50, current_user=None, db=db
    )


# ── Programme totals ─────────────────────────────────────────────────────────


def test_empty_ledger_reports_zeros_without_dividing(db):
    summary = _summary(db)

    assert summary.total_issued == 0
    assert summary.total_outstanding == 0
    assert summary.top_earners == []


def test_issued_sums_every_positive_row(db, make_member):
    member = make_member()
    _award(db, member, 100)
    _award(db, member, 50)

    assert _summary(db).total_issued == 150


def test_a_redemption_counts_as_redeemed_not_negative_issuance(db, make_member):
    _award(db, make_member(), -500, REDEMPTION)

    assert _summary(db).total_redeemed == 500


def test_outstanding_is_issued_minus_redeemed(db, make_member):
    member = make_member()
    _award(db, member, 800)
    _award(db, member, -500, REDEMPTION)

    assert _summary(db).total_outstanding == 300


def test_a_member_at_zero_is_not_counted_as_holding_points(db, make_member):
    member = make_member()
    _award(db, member, 250)
    _award(db, member, -250, REDEMPTION)

    assert _summary(db).members_with_points == 0


def test_top_earners_rank_by_lifetime_not_current_balance(db, make_member):
    spender = make_member(first_name="Spender")
    saver = make_member(first_name="Saver")
    _award(db, spender, 900)
    _award(db, spender, -800, REDEMPTION)
    _award(db, saver, 400)

    assert [e.first_name for e in _summary(db).top_earners] == ["Spender", "Saver"]


def test_reward_reach_counts_members_already_over_the_threshold(db, make_member):
    db.add(
        models.PawPointsReward(
            name="Pet Tag", points_required=500, reward_type="merchandise"
        )
    )
    _award(db, make_member(), 500)
    _award(db, make_member(), 499)
    db.flush()

    reach = _summary(db).reward_reach

    assert [(r.name, r.members_eligible) for r in reach] == [("Pet Tag", 1)]


def test_reward_reach_skips_retired_rewards(db, make_member):
    db.add(
        models.PawPointsReward(
            name="Retired",
            points_required=100,
            reward_type="merchandise",
            is_active=False,
        )
    )
    _award(db, make_member(), 5_000)
    db.flush()

    assert _summary(db).reward_reach == []


# ── Per-member balances ──────────────────────────────────────────────────────


def test_a_member_who_never_earned_appears_at_zero(db, make_member):
    make_member()

    assert [row.current_balance for row in _balances(db)] == [0]


def test_redeeming_debits_the_balance_but_never_lifetime_earned(db, make_member):
    member = make_member()
    _award(db, member, 1_000)
    _award(db, member, -400, REDEMPTION)

    row = _balances(db)[0]

    assert (row.current_balance, row.lifetime_earned) == (600, 1_000)


def test_a_balance_never_reads_negative(db, make_member):
    """A correction larger than the balance is an admin error, not a debt — the
    member endpoint floors at zero and the admin view must agree, or the two
    would quote different numbers for the same member."""
    member = make_member()
    _award(db, member, 100)
    _award(db, member, -300, REDEMPTION)

    assert _balances(db)[0].current_balance == 0


def test_rows_are_ordered_by_balance_descending(db, make_member):
    _award(db, make_member(first_name="Low"), 10)
    _award(db, make_member(first_name="High"), 900)

    assert [row.first_name for row in _balances(db)] == ["High", "Low"]


def test_search_matches_a_member_email(db, make_member):
    member = make_member()
    email = member.user.email

    assert [row.member_id for row in _balances(db, search=email)] == [member.id]


def test_search_excludes_non_matching_members(db, make_member):
    make_member(first_name="Alice")
    make_member(first_name="Bruno")

    assert [row.first_name for row in _balances(db, search="Alice")] == ["Alice"]


# ── One member's ledger ──────────────────────────────────────────────────────


def test_detail_returns_the_full_ledger_newest_first(db, make_member):
    member = make_member()
    _award(db, member, 100)
    _award(db, member, 200)

    detail = member_paw_points_detail(
        member_id=member.id, current_user=None, db=db
    )

    assert detail.balance.current_balance == 300
    assert len(detail.history) == 2


def test_detail_404s_for_an_unknown_member(db):
    import pytest
    from fastapi import HTTPException

    with pytest.raises(HTTPException) as raised:
        member_paw_points_detail(member_id="nope", current_user=None, db=db)

    assert raised.value.status_code == 404
