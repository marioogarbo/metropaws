"""Plan pricing rules — the multi-pet "Pack Discount".

Published policy (website FAQ): 15% off the annual plan for a member's SECOND
and THIRD pet, provided the primary pet is on the highest plan — i.e. the
discount applies only to plans STRICTLY CHEAPER than the best active plan the
member already pays for. The 4th+ pet pays full price. An equal-tier second
plan (e.g. Premium + Premium) is NOT discounted — "succeeding LOWER plans".

The rule is evaluated server-side at checkout time and re-evaluated on every
checkout (so a secondary pet's renewal keeps the discount only while the
primary plan is still active). The client never computes prices — it displays
quotes from GET /payments/quotes.

All amounts here are whole pesos (the legacy Payment.amount_php unit — NOT the
centavos used by reimbursements). The discount is rounded UP to the next whole
peso in the member's favor: final = price * (100 - pct) // 100.
"""
import os
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

import models

# Tunables (env-overridable, sane defaults). PACK_DISCOUNT_PERCENT=0 disables
# the discount entirely. PACK_DISCOUNT_MAX_PLAN_PETS caps how many pets can
# hold a plan before new activations stop qualifying (3 = pets #2 and #3 get
# the discount, per the published FAQ).
_DEF_PERCENT = 15
_DEF_MAX_PLAN_PETS = 3

# A pet's plan anchors the discount only while it is still active. Plans run
# 365 days (plan_utils grants services with a 1-year expiry). Legacy rows with
# plan_id set but no plan_activated_at (manual/seeded grants) count as active —
# generous, but a member whose real primary predates the timestamp column
# should not lose the published discount on a technicality.
_ACTIVE_WINDOW_DAYS = 365


def _percent() -> int:
    try:
        return int(os.getenv("PACK_DISCOUNT_PERCENT", str(_DEF_PERCENT)))
    except ValueError:
        return _DEF_PERCENT


def _max_plan_pets() -> int:
    try:
        return int(os.getenv("PACK_DISCOUNT_MAX_PLAN_PETS", str(_DEF_MAX_PLAN_PETS)))
    except ValueError:
        return _DEF_MAX_PLAN_PETS


def pack_discount_quote(
    db: Session,
    member: models.Member,
    plan: models.Plan,
    exclude_pet_id: str | None = None,
) -> dict:
    """Price `plan` for `member`, applying the Pack Discount when eligible.

    `exclude_pet_id` is the pet being paid for (exclude it from the anchor
    set so a renewal doesn't anchor on itself); pass None when quoting for a
    pet that doesn't exist yet (Add-a-Pet flow).

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

    pct = _percent()
    if pct <= 0:
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
