"""Monthly installment subscriptions and the vesting they gate.

Agreement Rev. 5A §5.2–§5.8. A monthly subscriber does not get full benefit
access on day one: the first cleared payment buys digital access only (§5.3), and
each class of benefit opens after a number of consecutive cleared payments set
per plan (§5.5). An annual member is never gated (§5.9) — expressed here as the
absence of a Subscription row, so nothing has to special-case the annual path.

**Emergency opens before planned services**, and that ordering is the whole point
of the design. The agreement's own §5.5 table contradicts itself in the planned
column — "After two (6) / three (8) / four (10) consecutive monthly payments",
words disagreeing with numerals — while its emergency column is unambiguous at
3/3/4. Under the words, emergency would open later than (Standard) or at the same
time as (De Luxe, Premium) the far larger planned benefit, which would make the
emergency control do nothing. Under the numerals it opens first and the column
means something. The numerals are therefore the intended values, and §5.4 agrees:
the requirement exists to stop enrolment "solely for immediate high-value
utilization", and the high-value pool is the preventive one behind planned
services. See context/features/document-system-alignment.md items 2 and 10.

Thresholds are columns on Plan, not constants here — §5.5 allows them to change
"through an officially approved Plan Schedule", and a name-keyed lookup is what
left the Emergency Wallet unreachable for months (see
reimbursement_utils.EMERGENCY_CATEGORY_NAMES).
"""
import enum
from datetime import date

from sqlalchemy.orm import Session

from app import models
from app.domain import reimbursement_utils


class BenefitClass(str, enum.Enum):
    """Which of the two §5.5 vesting thresholds a claim answers to."""
    emergency = "emergency"
    planned = "planned"


# A subscription that still represents a real arrangement. Cancelled rows are
# kept for history but gate nothing.
LIVE_STATUSES = (
    models.SubscriptionStatus.pending_first_payment,
    models.SubscriptionStatus.active,
    models.SubscriptionStatus.suspended,
)

_BENEFIT_LABELS = {
    BenefitClass.emergency: "Emergency support",
    BenefitClass.planned: "Planned services",
}


def for_pet(db: Session, pet: models.Pet) -> models.Subscription | None:
    """The pet's monthly arrangement, or None when the plan was paid annually.

    None is both the common case and the meaning of §5.9 — no monthly
    arrangement, nothing to vest.
    """
    return (
        db.query(models.Subscription)
        .filter(
            models.Subscription.pet_id == pet.id,
            models.Subscription.status.in_(LIVE_STATUSES),
        )
        .first()
    )


def benefit_class_for_category(category_name: str | None) -> BenefitClass:
    """Which threshold a claim under this service category has to clear.

    Defers to reimbursement_utils so the emergency decision has exactly one
    definition — the pool a claim draws from and the vesting it must clear are
    the same question, and they must never disagree.
    """
    if reimbursement_utils.is_emergency_category(category_name):
        return BenefitClass.emergency
    return BenefitClass.planned


def threshold(plan: models.Plan | None, benefit: BenefitClass) -> int:
    """Consecutive cleared payments this plan requires before `benefit` opens.
    0 means no waiting period."""
    if plan is None:
        return 0
    if benefit is BenefitClass.emergency:
        return plan.vesting_emergency_payments or 0
    return plan.vesting_planned_payments or 0


def eligible_since(subscription: models.Subscription, benefit: BenefitClass) -> date | None:
    """The date this benefit class became available, or None if it hasn't."""
    if benefit is BenefitClass.emergency:
        return subscription.emergency_eligible_since
    return subscription.planned_eligible_since


def payments_remaining(subscription: models.Subscription, benefit: BenefitClass) -> int:
    """How many more consecutive payments are needed. 0 means vested."""
    needed = threshold(subscription.plan, benefit)
    return max(0, needed - (subscription.consecutive_payments or 0))


def _stamp_eligible(
    subscription: models.Subscription, benefit: BenefitClass, on: date
) -> None:
    if benefit is BenefitClass.emergency:
        subscription.emergency_eligible_since = on
    else:
        subscription.planned_eligible_since = on


def record_cleared_payment(subscription: models.Subscription, paid_on: date) -> None:
    """Count one cleared monthly payment (§5.4) and stamp any threshold it crosses.

    The stamp happens here, at the moment the counter crosses, because §5.8 needs
    the DATE a benefit became available and that can never be recomputed
    afterwards — a §5.6 reset destroys the run of payments that produced it.

    Does not set `next_due_on` or `last_payment_at`: those belong to the billing
    cycle, which is not built yet.
    """
    subscription.consecutive_payments = (subscription.consecutive_payments or 0) + 1
    subscription.status = models.SubscriptionStatus.active
    for benefit in BenefitClass:
        if eligible_since(subscription, benefit) is not None:
            continue
        if payments_remaining(subscription, benefit) > 0:
            continue
        _stamp_eligible(subscription, benefit, paid_on)


def claim_block_reason(
    subscription: models.Subscription,
    benefit: BenefitClass,
    service_date: date,
) -> str | None:
    """Why this claim can't be filed under a monthly subscription, or None.

    Three refusals, in the order the agreement applies them: suspended for
    non-payment (§5.6), not yet vested (§5.5), and vested now but the service
    predates eligibility (§5.8).
    """
    if subscription.status == models.SubscriptionStatus.suspended:
        return (
            "This membership is suspended after a missed payment. Settle the "
            "outstanding installment to use benefits again."
        )

    remaining = payments_remaining(subscription, benefit)
    if remaining > 0:
        needed = threshold(subscription.plan, benefit)
        payment_word = "payment" if remaining == 1 else "payments"
        return (
            f"{_BENEFIT_LABELS[benefit]} open after {needed} consecutive monthly "
            f"payments — {remaining} more {payment_word} to go."
        )

    began = eligible_since(subscription, benefit)
    if began is not None and service_date < began:
        return (
            f"{_BENEFIT_LABELS[benefit]} became available on "
            f"{began.strftime('%d %b %Y')}. A service from before that date isn't "
            "covered, even though the payments are now complete."
        )

    return None
