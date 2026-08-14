"""Plan pricing rules — the multi-pet "Pack Discount".

Published policy (website FAQ): 15% off the annual plan for a member's SECOND
and THIRD pet, provided the primary pet is on the highest plan — i.e. the
discount applies only to plans STRICTLY CHEAPER than the best active plan the
member already pays for. The 4th+ pet pays full price. An equal-tier second
plan (e.g. Premium + Premium) is NOT discounted — "succeeding LOWER plans".

The rule is evaluated server-side at checkout time, against the member's other
pets as they stand right then. The client never computes prices — it displays
quotes from GET /payments/quotes.

FIRST ACTIVATION ONLY (client decision 2026-07-29): the discount is a joining
incentive for ADDING a pet, so it applies only to a pet's FIRST plan
activation. Mid-term upgrades and renewals both pay full price. A different
renewal-time discount may be introduced later — that would be its own rule, not
this one. Callers pass the plan_term_utils eligibility code as
``purchase_code``; see _DISCOUNT_ELIGIBLE_CODES.

All amounts here are whole pesos (the legacy Payment.amount_php unit — NOT the
centavos used by reimbursements). The discount is rounded UP to the next whole
peso in the member's favor: final = price * (100 - pct) // 100.

ADMIN-CONTROLLED (2026-07-28): whether the discount is on and what percent it
uses are live settings, editable from the website Settings page with no
redeploy — see pack_discount_settings() and routers/settings.py's
GET/PUT /settings/pack-discount. PACK_DISCOUNT_PERCENT (env) is consulted only
as the fresh-install default, before an admin has ever saved a value.
"""
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

import config
import models

PACK_DISCOUNT_ENABLED_KEY = "pack_discount_enabled"
PACK_DISCOUNT_PERCENT_KEY = "pack_discount_percent"

# plan_term_utils.purchase_eligibility codes that may carry the Pack Discount.
# ONLY 'new' — this pet's first plan (the Add-a-Pet / register-a-pet case).
# 'upgrade' and 'renewal' are both deliberately excluded: the discount is a
# joining incentive for adding a pet, not a standing multi-pet rate. If a
# renewal incentive is wanted later, add it as its own rule/percent rather than
# widening this set.
_DISCOUNT_ELIGIBLE_CODES = {"new"}

# Env-only fallback default (fresh install, admin hasn't saved a value yet).
_DEF_PERCENT = 15
# Not admin-exposed (no client request for it) — caps how many pets can hold a
# plan before new activations stop qualifying (3 = pets #2 and #3 get the
# discount, per the published FAQ).
_DEF_MAX_PLAN_PETS = 3

# A pet's plan anchors the discount only while it is still active. Plans run
# 365 days (plan_utils grants services with a 1-year expiry). Legacy rows with
# plan_id set but no plan_activated_at (manual/seeded grants) count as active —
# generous, but a member whose real primary predates the timestamp column
# should not lose the published discount on a technicality.
_ACTIVE_WINDOW_DAYS = 365


def _default_percent_from_env() -> int:
    # Deliberately tolerant rather than config.env_int, which raises: a typo in
    # a pricing setting must not take checkout down with it.
    try:
        return int(config.env("PACK_DISCOUNT_PERCENT", str(_DEF_PERCENT)))
    except ValueError:
        return _DEF_PERCENT


def _max_plan_pets() -> int:
    try:
        return int(config.env("PACK_DISCOUNT_MAX_PLAN_PETS", str(_DEF_MAX_PLAN_PETS)))
    except ValueError:
        return _DEF_MAX_PLAN_PETS


def pack_discount_settings(db: Session) -> tuple[bool, int]:
    """Effective (enabled, percent) — the ONLY function pack_discount_quote
    consults for whether/how much to discount. Backed by the same AppSetting
    key/value table as booking_enabled etc.; falls back to the env default
    for whichever field the admin hasn't saved yet."""
    enabled_row = (
        db.query(models.AppSetting)
        .filter(models.AppSetting.key == PACK_DISCOUNT_ENABLED_KEY)
        .first()
    )
    percent_row = (
        db.query(models.AppSetting)
        .filter(models.AppSetting.key == PACK_DISCOUNT_PERCENT_KEY)
        .first()
    )
    enabled = (enabled_row.value == "true") if enabled_row else True
    try:
        percent = int(percent_row.value) if percent_row else _default_percent_from_env()
    except ValueError:
        percent = _default_percent_from_env()
    return enabled, percent


def pack_discount_quote(
    db: Session,
    member: models.Member,
    plan: models.Plan,
    exclude_pet_id: str | None = None,
    purchase_code: str | None = None,
) -> dict:
    """Price `plan` for `member`, applying the Pack Discount when eligible.

    `exclude_pet_id` is the pet being paid for (exclude it from the anchor
    set so a renewal doesn't anchor on itself); pass None when quoting for a
    pet that doesn't exist yet (Add-a-Pet flow).

    `purchase_code` is the plan_term_utils.purchase_eligibility code for this
    (pet, plan) pair. Only _DISCOUNT_ELIGIBLE_CODES carry the discount — an
    'upgrade' pays full price. None means "no purchase context" and keeps the
    discount, so a caller that doesn't know the code can't silently lose it.

    Returns whole-peso ints: {full_php, discount_php, final_php,
    discount_percent} — discount_php is 0 when not eligible.
    """
    full = plan.price
    no_discount = {
        "full_php": full,
        "discount_php": 0,
        "final_php": full,
        "discount_percent": 0,
    }

    if purchase_code is not None and purchase_code not in _DISCOUNT_ELIGIBLE_CODES:
        return no_discount

    enabled, pct = pack_discount_settings(db)
    if not enabled or pct <= 0:
        return no_discount

    cutoff = datetime.now(timezone.utc) - timedelta(days=_ACTIVE_WINDOW_DAYS)
    query = (
        db.query(models.Pet.plan_activated_at, models.Plan.price)
        .join(models.Plan, models.Pet.plan_id == models.Plan.id)
        .filter(models.Pet.member_id == member.id)
    )
    if exclude_pet_id:
        query = query.filter(models.Pet.id != exclude_pet_id)
    rows = query.all()

    def _is_active(activated) -> bool:
        if activated is None:
            return True
        # Postgres returns tz-aware datetimes; guard the naive case anyway so
        # a driver/backend quirk can never crash the money path.
        if activated.tzinfo is None:
            activated = activated.replace(tzinfo=timezone.utc)
        return activated >= cutoff

    anchor_prices = [price for (activated, price) in rows if _is_active(activated)]

    # This activation would make the pet the (len+1)-th pet with a plan; only
    # pets #2..#MAX qualify, and only for a plan cheaper than the current best.
    if not anchor_prices or len(anchor_prices) >= _max_plan_pets():
        return no_discount
    if full >= max(anchor_prices):
        return no_discount

    final = full * (100 - pct) // 100
    return {
        "full_php": full,
        "discount_php": full - final,
        "final_php": final,
        "discount_percent": pct,
    }
