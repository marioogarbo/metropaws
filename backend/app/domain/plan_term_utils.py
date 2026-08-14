"""Plan term math and purchase eligibility — upgrade / renewal rules.

Client rules (confirmed 2026-07-27):

- A pet's plan runs 365 days from ``plan_activated_at``.
- MID-TERM UPGRADE: while the plan is active (outside the renewal window), the
  member may buy a STRICTLY higher-priced plan for that pet, and only while
  this term's benefits are completely untouched — zero used AND zero pending in
  both wallet pools, and zero service sessions used. The new plan fully
  REPLACES the old one (no carry-over) and the plan year restarts.
- Same-or-lower plan mid-term: blocked.
- RENEWAL WINDOW: within the final ``RENEWAL_WINDOW_DAYS`` (default 30) of the
  term, or any time after expiry, ANY plan may be purchased (same, higher, or
  lower) with no untouched requirement. Renewal also fully replaces benefits.
- EXPIRY: once the term ends, new reimbursement claims are blocked until the
  plan is renewed (enforced in routers/reimbursements.py).

Tier comparison is BY PRICE (same convention as pricing_utils). This module is
the single source of truth — checkout, the payments-disabled activate-plan
path, the quotes endpoint, and the wallet endpoint all call it.

Legacy pets with ``plan_id`` set but ``plan_activated_at`` NULL (manual/seeded
grants) are treated as ACTIVE WITH NO EXPIRY: they can upgrade while untouched
and never hit the expiry gate; the first re-grant stamps a real date.
"""
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app import config
from app import models
from app.domain import reimbursement_utils
from app.datetime_utils import aware

PLAN_TERM_DAYS = 365

_DEF_RENEWAL_WINDOW_DAYS = 30

# Eligibility codes. Allowed: new / upgrade / renewal. Blocked: the rest.
ALLOWED_CODES = {"new", "upgrade", "renewal"}

ELIGIBILITY_MESSAGES = {
    "current_plan": (
        "This pet already has this plan. You can renew it in the last "
        "{window} days of the plan year."
    ),
    "lower_plan": (
        "Switching to a lower or equal plan isn't available mid-year — you can "
        "change plans at renewal time."
    ),
    "benefits_used": (
        "Upgrades are available only while this year's benefits are unused — "
        "you can change plans at renewal time."
    ),
}


def renewal_window_days() -> int:
    # Tolerant on purpose (see pricing_utils._default_percent_from_env): a bad
    # value here must not block every purchase.
    try:
        return int(config.env("RENEWAL_WINDOW_DAYS", str(_DEF_RENEWAL_WINDOW_DAYS)))
    except ValueError:
        return _DEF_RENEWAL_WINDOW_DAYS


def plan_term(pet: models.Pet) -> tuple[datetime, datetime] | None:
    """(activated_at, expires_at) of the pet's current plan term, or None when
    the pet has no plan OR a legacy plan with no activation date (no expiry)."""
    if not pet.plan_id or pet.plan_activated_at is None:
        return None
    start = aware(pet.plan_activated_at)
    return start, start + timedelta(days=PLAN_TERM_DAYS)


def plan_status(pet: models.Pet) -> str:
    """'none' | 'active' | 'renewal_window' | 'expired'.

    Legacy plans without an activation date report 'active' (no expiry).
    """
    if not pet.plan_id:
        return "none"
    term = plan_term(pet)
    if term is None:
        return "active"
    _start, expires = term
    now = datetime.now(timezone.utc)
    if now >= expires:
        return "expired"
    if now >= expires - timedelta(days=renewal_window_days()):
        return "renewal_window"
    return "active"


def benefits_untouched(db: Session, pet: models.Pet) -> bool:
    """True when NOTHING of this term's benefits has been consumed or reserved:
    both wallet pools show zero used and zero pending (rejected claims don't
    count — wallet_usage ignores them), and no service session has been used.

    used_sessions is per-term going forward (replace-grant recreates the rows
    on every grant); legacy rows carrying historical usage conservatively block
    the upgrade, which admins can resolve at renewal time.
    """
    if any((ps.used_sessions or 0) > 0 for ps in pet.pet_services):
        return False
    return reimbursement_utils.wallet_usage(db, pet) == (0, 0, 0, 0)


def purchase_eligibility(
    db: Session, pet: models.Pet, plan: models.Plan
) -> tuple[bool, str]:
    """May this member buy `plan` for `pet` right now?

    Returns (allowed, code): allowed codes 'new' / 'upgrade' / 'renewal';
    blocked codes 'current_plan' / 'lower_plan' / 'benefits_used' (message in
    ELIGIBILITY_MESSAGES, .format(window=renewal_window_days())).
    """
    status = plan_status(pet)
    if status == "none":
        return True, "new"
    if status in ("renewal_window", "expired"):
        return True, "renewal"

    # Active mid-term: only a strictly higher plan, and only while untouched.
    current_price = pet.plan.price if pet.plan else 0
    if plan.id == pet.plan_id:
        return False, "current_plan"
    if plan.price <= current_price:
        return False, "lower_plan"
    if not benefits_untouched(db, pet):
        return False, "benefits_used"
    return True, "upgrade"


def eligibility_message(code: str) -> str:
    """Human-readable block reason for HTTP details (shown verbatim in-app)."""
    template = ELIGIBILITY_MESSAGES.get(code, "This plan isn't available right now.")
    return template.format(window=renewal_window_days())
