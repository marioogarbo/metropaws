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
import calendar
import enum
from datetime import date, datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app import config
from app import models
from app.domain import reimbursement_utils

# How late an installment may be before the run of consecutive payments is
# broken (§5.6). Env-tunable because it is a collections policy, not a rule of
# the agreement — §5.6 leaves the response to MetroPaws' discretion.
GRACE_DAYS = config.env_int("SUBSCRIPTION_GRACE_DAYS", 7)


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


def start_subscription(
    db: Session, pet: models.Pet, plan: models.Plan
) -> models.Subscription:
    """Open (or reopen) this pet's monthly arrangement, awaiting its first payment.

    Reuses the pet's existing row rather than inserting a second one — `pet_id`
    is unique, and a member who cancelled and came back must not collide with
    their own history. Reopening clears the counter and both eligibility stamps:
    the new arrangement earns its vesting from scratch, which is what §5.8 means
    by earlier payments not making prior services payable.
    """
    subscription = (
        db.query(models.Subscription)
        .filter(models.Subscription.pet_id == pet.id)
        .first()
    )
    if subscription is None:
        subscription = models.Subscription(member_id=pet.member_id, pet_id=pet.id)
        db.add(subscription)

    subscription.plan_id = plan.id
    subscription.status = models.SubscriptionStatus.pending_first_payment
    subscription.consecutive_payments = 0
    subscription.emergency_eligible_since = None
    subscription.planned_eligible_since = None
    subscription.next_due_on = None
    subscription.cancelled_at = None
    subscription.suspended_at = None
    db.flush()
    return subscription


def cancel_for_pet(db: Session, pet: models.Pet) -> None:
    """End any live instalment arrangement for this pet.

    Called when the pet's plan is bought OUTRIGHT. Nobody pays monthly and
    annually for the same plan at once, and leaving the row behind is worse than
    untidy: `for_pet` would keep finding it, so a member who has just paid a full
    year up front would still be gated as an unvested subscriber, still shown
    "Vesting in Progress", and still described as paying monthly.

    Idempotent, and a no-op for the overwhelming majority of pets, which have no
    subscription at all.
    """
    subscription = for_pet(db, pet)
    if subscription is None:
        return
    subscription.status = models.SubscriptionStatus.cancelled
    subscription.cancelled_at = datetime.now(timezone.utc)
    subscription.next_due_on = None
    db.flush()


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


def next_due_after(paid_on: date) -> date:
    """The date the following installment falls due — one calendar month on.

    Clamped to the length of the target month, so a subscription started on the
    31st stays on the 31st where the month allows it and lands on the last day
    where it does not, rather than drifting earlier every short month.
    """
    year = paid_on.year + (paid_on.month // 12)
    month = paid_on.month % 12 + 1
    return date(year, month, min(paid_on.day, calendar.monthrange(year, month)[1]))


def is_in_default(subscription: models.Subscription) -> bool:
    """True when the next installment is overdue by more than the grace window.

    **Derived, not swept.** This backend has no scheduler or background worker,
    so nothing could mark a subscription late on a timer. Reading it from
    `next_due_on` the way plan_term_utils reads expiry from `plan_activated_at`
    means default is always current without a cron job existing to be forgotten.

    Reads the clock in UTC, matching plan_status. A subscription that has never
    had a cleared payment has no due date and so cannot be in default — it is
    simply not started.
    """
    if subscription.status == models.SubscriptionStatus.cancelled:
        return False
    if subscription.next_due_on is None:
        return False
    today = datetime.now(timezone.utc).date()
    return today > subscription.next_due_on + timedelta(days=GRACE_DAYS)


def _stamp_eligible(
    subscription: models.Subscription, benefit: BenefitClass, on: date
) -> None:
    if benefit is BenefitClass.emergency:
        subscription.emergency_eligible_since = on
    else:
        subscription.planned_eligible_since = on


def _restart_run(subscription: models.Subscription) -> None:
    """Break the run of consecutive payments and surrender both eligibilities.

    The stamps go with the counter deliberately. §5.8 says earlier payments do
    not make prior services payable, so a re-earned eligibility must carry a NEW
    date — keeping the old stamp would leave a member covered for the months they
    were in default.
    """
    subscription.consecutive_payments = 0
    subscription.emergency_eligible_since = None
    subscription.planned_eligible_since = None


def record_cleared_payment(subscription: models.Subscription, paid_on: date) -> None:
    """Count one cleared monthly payment (§5.4) and stamp any threshold it crosses.

    Applies the §5.6 policy chosen on 2026-08-17: an installment that arrives
    after the grace window has passed **restarts the run at one** rather than
    continuing it. Nothing sweeps for this — the lateness is judged here, at the
    next payment, which is the only moment the answer can change.

    The stamp happens at the moment the counter crosses, because §5.8 needs the
    DATE a benefit became available and a restart destroys the run that produced
    it.

    Sets `next_due_on`. Leaves `last_payment_at` to the caller, which holds the
    real timestamp; this function only has the date.
    """
    if is_in_default(subscription):
        _restart_run(subscription)
    subscription.consecutive_payments = (subscription.consecutive_payments or 0) + 1
    subscription.status = models.SubscriptionStatus.active
    subscription.next_due_on = next_due_after(paid_on)
    for benefit in BenefitClass:
        if eligible_since(subscription, benefit) is not None:
            continue
        if payments_remaining(subscription, benefit) > 0:
            continue
        _stamp_eligible(subscription, benefit, paid_on)


def benefit_available(
    subscription: models.Subscription | None, benefit: BenefitClass
) -> bool:
    """Whether this class of benefit can be drawn on right now.

    Exists so the wallet can SHOW what a member may actually use. Displaying a
    full pool to someone who is not vested invites them to book a service the
    claim gate will then refuse — the balance is real, but it is not yet theirs
    to spend.

    None means an annual member, who is never gated (§5.9).
    """
    if subscription is None:
        return True
    if subscription.status == models.SubscriptionStatus.suspended:
        return False
    if is_in_default(subscription):
        return False
    return payments_remaining(subscription, benefit) == 0


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
    if subscription.status == models.SubscriptionStatus.suspended or is_in_default(
        subscription
    ):
        return (
            "This membership is suspended after a missed payment. Settle the "
            "outstanding installment to use benefits again — note that paying "
            "late restarts the qualifying period."
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
