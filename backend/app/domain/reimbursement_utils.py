"""Shared reimbursement logic: per-plan wallet pools, usage, and notifications.

Kept separate from the routers so the member-facing wallet and the admin review
flow compute remaining benefit the exact same way. All amounts are centavos.

Two pools per plan (client decision 2026-07-16): a claim filed under an emergency
category draws from the Emergency Wallet; every other category draws from the
Preventive Wellness Wallet. The pool is chosen by service-category NAME (no
is_emergency DB flag), mirroring the grooming-cooldown name-match pattern.

That name match is the weak point: it silently misroutes money when a category is
named something the set doesn't list, and it did — see EMERGENCY_CATEGORY_NAMES.
"""
from sqlalchemy.orm import Session

from app import models
from app import email_utils


# Statuses that consume benefit (count toward "used").
USED_STATUSES = (models.ReimbursementStatus.approved, models.ReimbursementStatus.paid)
# Open statuses awaiting a decision (count toward "pending").
PENDING_STATUSES = (
    models.ReimbursementStatus.pending,
    models.ReimbursementStatus.under_review,
    models.ReimbursementStatus.needs_info,
)

# Category names (lower-cased) that draw from the Emergency Wallet instead of the
# Preventive Wellness Wallet. Same name-match approach as the grooming cooldown.
#
# Both spellings are listed because seed.py creates two different things: the
# wallet-bucket category "Emergency" and the session category "Emergency
# Stabilization". Only the latter exists in dev or production, so matching
# "emergency" alone left the Emergency Wallet unreachable — every emergency claim
# drew from the much larger Preventive Wellness pool, and emergency qualified for
# direct-to-provider pay because that rule is defined as "not emergency".
# Verified against both databases 2026-08-15.
#
# Renaming the category in the admin UI breaks this again. The durable fix is an
# admin-editable ServiceType.is_emergency flag.
EMERGENCY_CATEGORY_NAMES = {"emergency", "emergency stabilization"}


def is_emergency_category(name: str | None) -> bool:
    """True if a claim under this service-category name draws from the Emergency
    Wallet rather than the Preventive Wellness Wallet."""
    return bool(name) and name.strip().lower() in EMERGENCY_CATEGORY_NAMES


def is_direct_pay_eligible_category(name: str | None) -> bool:
    """True if this service category may use payout_target=provider (MetroPaws
    pays the clinic/groomer directly instead of reimbursing the member).

    v1 rule: any scheduled, non-emergency category qualifies — emergency claims
    always stay on the pay-then-reimburse flow, since they need faster turnaround
    than the current fully-manual admin review can reliably guarantee. Kept as its
    own function (rather than inlining `not is_emergency_category(...)` at call
    sites) so this rule can diverge later without touching callers.
    """
    return not is_emergency_category(name)


def is_direct_pay_available(member: models.Member, global_enabled: bool) -> bool:
    """Whether this member may use payout_target=provider right now.

    The global `direct_provider_payment_enabled` setting is the default; a
    per-member override wins when set. NULL override — every member until an
    admin says otherwise — follows the global switch, so turning the feature on
    still reaches everyone, and restricting one abuser no longer means turning it
    off for all. See Member.direct_pay_enabled.

    Takes the resolved global as an argument rather than reading the setting
    itself: the value lives in routers.settings, and a utils module reaching back
    into a router would invert the dependency.
    """
    if member.direct_pay_enabled is not None:
        return member.direct_pay_enabled
    return global_enabled


def plan_wallet_centavos(db: Session, plan_id: str | None) -> int:
    """The plan's annual Preventive Wellness Wallet — the pool non-emergency
    claims draw from. Per-category PlanService.reimbursement_cap_centavos is
    legacy and no longer consulted."""
    if not plan_id:
        return 0
    plan = db.query(models.Plan).filter(models.Plan.id == plan_id).first()
    return (plan.reimbursement_wallet_centavos if plan else 0) or 0


def plan_emergency_wallet_centavos(db: Session, plan_id: str | None) -> int:
    """The plan's annual Emergency Wallet — the pool "Emergency"-category claims
    draw from."""
    if not plan_id:
        return 0
    plan = db.query(models.Plan).filter(models.Plan.id == plan_id).first()
    return (plan.emergency_wallet_centavos if plan else 0) or 0


def wallet_usage(
    db: Session,
    pet: models.Pet,
    exclude_id: str | None = None,
    lock: bool = False,
) -> tuple[int, int, int, int]:
    """Return (prev_used, prev_pending, emg_used, emg_pending) for one pet this
    period, bucketed by pool: emergency-category claims into the emergency totals,
    all others into the preventive totals.

    The benefit period starts at the pet's plan activation (annual plans), so
    claims for services dated before activation don't count against the current
    allowance. Set ``lock=True`` to row-lock the claim set while approving, which
    serializes concurrent approvals against the same wallet.
    """
    q = db.query(models.Reimbursement).filter(
        models.Reimbursement.pet_id == pet.id,
    )
    if pet.plan_activated_at is not None:
        q = q.filter(models.Reimbursement.service_date >= pet.plan_activated_at.date())
    if exclude_id is not None:
        q = q.filter(models.Reimbursement.id != exclude_id)
    if lock:
        q = q.with_for_update()

    prev_used = prev_pending = emg_used = emg_pending = 0
    for r in q.all():
        emergency = is_emergency_category(r.service_type.name if r.service_type else None)
        if r.status in USED_STATUSES:
            amount = r.approved_amount_centavos or 0
            if emergency:
                emg_used += amount
            else:
                prev_used += amount
        elif r.status in PENDING_STATUSES:
            amount = r.claimed_amount_centavos
            if emergency:
                emg_pending += amount
            else:
                prev_pending += amount
    return prev_used, prev_pending, emg_used, emg_pending


def _peso(centavos) -> str:
    return f"₱{(centavos or 0) / 100:,.2f}"


def _notification_content(claim: models.Reimbursement, status: str, service: str) -> tuple[str, str]:
    """(title, body) for the in-app notification per status."""
    is_provider_target = claim.payout_target == models.PayoutTarget.provider
    if status == "approved":
        if is_provider_target:
            return (
                "Payment approved 🎉",
                f"Your request to pay {claim.provider_name} directly for your {service} appointment "
                f"was approved — {_peso(claim.approved_amount_centavos)}.",
            )
        return (
            "Claim approved 🎉",
            f"Your {service} claim was approved for {_peso(claim.approved_amount_centavos)}.",
        )
    if status == "paid":
        if is_provider_target:
            return (
                "Provider paid",
                f"We paid {claim.provider_name} {_peso(claim.approved_amount_centavos)} for your "
                f"{service} — no need to bring cash to your appointment.",
            )
        return (
            "Reimbursement released",
            f"{_peso(claim.approved_amount_centavos)} for your {service} claim has been paid out.",
        )
    if status == "needs_info":
        note = f" Note: {claim.admin_notes}" if claim.admin_notes else ""
        return (
            "Action needed on your claim",
            f"We need a clearer or more complete receipt for your {service} claim.{note}",
        )
    if status == "rejected":
        note = f" Reason: {claim.admin_notes}" if claim.admin_notes else ""
        return ("Claim update", f"Your {service} claim was not approved.{note}")
    return ("Claim update", f"Your {service} claim status changed to {status.replace('_', ' ')}.")


def notify_status(db: Session, claim: models.Reimbursement) -> None:
    """Best-effort status-change notification (in-app row + email).

    Never raises — a notification/mail failure must not break the API."""
    status = claim.status.value if hasattr(claim.status, "value") else str(claim.status)
    service = claim.service_type.name if claim.service_type else "your service"

    # In-app notification (bell icon).
    try:
        title, body = _notification_content(claim, status, service)
        db.add(
            models.Notification(
                member_id=claim.member_id,
                title=title,
                body=body,
                type="reimbursement",
                reference_id=claim.id,
            )
        )
        db.commit()
    except Exception:
        db.rollback()

    # Email.
    try:
        member = claim.member or (
            db.query(models.Member).filter(models.Member.id == claim.member_id).first()
        )
        if not member or not member.email:
            return
        target = claim.payout_target.value if hasattr(claim.payout_target, "value") else str(claim.payout_target)
        email_utils.send_claim_status_email(
            to_email=member.email,
            member_name=member.first_name,
            status=status,
            service_name=service,
            claimed_centavos=claim.claimed_amount_centavos,
            approved_centavos=claim.approved_amount_centavos,
            admin_note=claim.admin_notes,
            payout_target=target,
            provider_name=claim.provider_name if target == "provider" else None,
        )
    except Exception:
        # Swallow — a mail outage should never fail the request.
        pass
