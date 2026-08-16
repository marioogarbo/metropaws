"""The member-facing status labels of Agreement Rev. 5A §5.7.

§5.7 tells members the app "may display status labels including Pending
Onboarding, Digital Access Active, Vesting in Progress, Fully Service-Eligible,
Authorization Restricted, Suspended, Expired or Under Review", and makes the
member responsible for checking that status before requesting a service. Holding
someone responsible for reading a status the product never shows is a weak
position, which is why this exists.

**Derived, never stored.** The same choice plan_term_utils.plan_status makes: a
stored label drifts from the facts that produce it, and every one of these labels
is already implied by the plan term, the subscription counter and the direct-pay
override.

**"Under Review" is deliberately absent.** Nothing in the data model expresses it
— there is no review flag on Member or Pet — and inventing a state the system
cannot enter would put a label in front of members that never means anything.
§5.7 says "may display ... including", so a subset is faithful to it.
"""
import enum

from app import models
from app.domain import plan_term_utils
from app.domain import subscription_utils


class MembershipStatus(str, enum.Enum):
    """Wire values stay snake_case like every other enum in models.py; the
    contract's exact wording lives in LABELS so the app never hardcodes it and
    the two cannot drift."""
    pending_onboarding = "pending_onboarding"
    digital_access_active = "digital_access_active"
    vesting_in_progress = "vesting_in_progress"
    fully_service_eligible = "fully_service_eligible"
    authorization_restricted = "authorization_restricted"
    suspended = "suspended"
    expired = "expired"


LABELS = {
    MembershipStatus.pending_onboarding: "Pending Onboarding",
    MembershipStatus.digital_access_active: "Digital Access Active",
    MembershipStatus.vesting_in_progress: "Vesting in Progress",
    MembershipStatus.fully_service_eligible: "Fully Service-Eligible",
    MembershipStatus.authorization_restricted: "Authorization Restricted",
    MembershipStatus.suspended: "Suspended",
    MembershipStatus.expired: "Expired",
}


def status_for(
    pet: models.Pet,
    subscription: models.Subscription | None,
    member: models.Member,
) -> MembershipStatus:
    """This pet's §5.7 status. `subscription` is None for an annual member.

    Precedence runs from the states that STOP a member using benefits down to
    the ones that merely qualify how, so the label always names the strongest
    thing standing in their way:

    1. Suspended — §5.6 non-payment, whether an admin set it or the installment
       is simply overdue past the grace window (that half is derived, so it needs
       no scheduler). Outranks vesting entirely: a fully vested subscriber in
       default still cannot claim.
    2. Expired — the plan year ended (§5.9 term), which blocks new claims.
    3. Pending Onboarding — no plan, or a monthly arrangement whose first
       installment has not cleared. §5.3 grants digital access only *after* that
       first cleared payment, so before it there is nothing else to report.
    4. Authorization Restricted — an admin has switched this member off direct
       provider pay. It ranks above eligibility because it is the more specific
       truth; the member can still claim reimbursement, and it is *authorization*
       that is restricted, which is exactly what §5.7 means by the term. The
       mapping is the one already cited in the migration that added the override.
    5. Vesting ladder, for monthly subscribers only. Each rung is a capability
       the member actually has, not just a count of payments:
       Digital Access Active (app only, nothing claimable) → Vesting in Progress
       (emergency cover reached, planned services not yet) → Fully
       Service-Eligible (both).
    6. Fully Service-Eligible — an annual member with a live plan. §5.9 exempts
       them from vesting outright.
    """
    if subscription is not None and (
        subscription.status == models.SubscriptionStatus.suspended
        or subscription_utils.is_in_default(subscription)
    ):
        return MembershipStatus.suspended

    plan_state = plan_term_utils.plan_status(pet)
    if plan_state == "expired":
        return MembershipStatus.expired
    if plan_state == "none":
        return MembershipStatus.pending_onboarding

    if subscription is not None and (subscription.consecutive_payments or 0) == 0:
        return MembershipStatus.pending_onboarding

    if member.direct_pay_enabled is False:
        return MembershipStatus.authorization_restricted

    if subscription is None:
        return MembershipStatus.fully_service_eligible

    emergency_due = subscription_utils.payments_remaining(
        subscription, subscription_utils.BenefitClass.emergency
    )
    planned_due = subscription_utils.payments_remaining(
        subscription, subscription_utils.BenefitClass.planned
    )
    if planned_due == 0:
        return MembershipStatus.fully_service_eligible
    if emergency_due == 0:
        return MembershipStatus.vesting_in_progress
    return MembershipStatus.digital_access_active


def label_for(status: MembershipStatus) -> str:
    """The §5.7 wording for a status, served alongside the wire value so the app
    displays the contract's words without embedding them in a release."""
    return LABELS[status]
