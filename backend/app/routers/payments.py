import json
import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session

from app import auth as auth_utils
from app import config
from app import models
from app import paymongo
from app.domain import plan_term_utils
from app.domain import pricing_utils
from app.domain import subscription_utils
from app import schemas
from app.database import get_db
from app.domain.plan_utils import grant_plan_to_member, grant_plan_to_pet
from app.routers.settings import get_payments_enabled

logger = logging.getLogger("metropaws.payments")

router = APIRouter(prefix="/payments", tags=["payments"])


@router.post("/checkout", response_model=schemas.CheckoutResponse)
async def create_checkout(
    payload: schemas.CheckoutRequest,
    current_user: models.User = Depends(auth_utils.require_member),
    db: Session = Depends(get_db),
):
    if not get_payments_enabled(db):
        raise HTTPException(
            status_code=400,
            detail="Payments are currently disabled. Select a plan directly to get access.",
        )

    member = current_user.member
    if not member:
        raise HTTPException(status_code=400, detail="Member profile not found")

    plan = (
        db.query(models.Plan)
        .filter(models.Plan.id == payload.plan_id, models.Plan.is_active == True)
        .first()
    )
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    # Checkout Session success/cancel URLs must be http(s); they target the
    # backend return pages below, which deep-link back into the app. They
    # default to this environment's own BASE_URL so a dev run never sends a
    # member back to the production service.
    base_url = config.env("BASE_URL", "http://localhost:8000").rstrip("/")
    success_base = config.env("PAYMONGO_SUCCESS_REDIRECT", f"{base_url}/payments/return/success")
    failure_base = config.env("PAYMONGO_FAILURE_REDIRECT", f"{base_url}/payments/return/failed")

    pet = (
        db.query(models.Pet)
        .filter(models.Pet.id == payload.pet_id, models.Pet.member_id == member.id)
        .first()
    )
    if not pet:
        raise HTTPException(status_code=404, detail="Pet not found")

    # Upgrade/renewal rules (plan_term_utils): mid-term only a strictly higher
    # plan with untouched benefits; same/lower plans wait for the renewal
    # window. Enforced server-side — the app mirrors this state but the 409
    # here is the authority (its detail is shown verbatim in-app).
    allowed, code = plan_term_utils.purchase_eligibility(db, pet, plan)
    if not allowed:
        raise HTTPException(
            status_code=409, detail=plan_term_utils.eligibility_message(code)
        )

    subscription = None
    if payload.cadence == "monthly":
        if not plan.price_monthly:
            raise HTTPException(
                status_code=400,
                detail=f"The {plan.name} plan isn't available on monthly instalments.",
            )
        # No Pack Discount on instalments. It is 15% off an ANNUAL plan as a
        # joining incentive for a second pet; applying it per instalment would
        # discount the whole year twelve times over.
        amount_php, discount_php = plan.price_monthly, 0
        subscription = subscription_utils.start_subscription(db, pet, plan)
        line_item_name = f"MetroPaws {plan.name} Plan — first monthly instalment"
    else:
        # Server-authoritative price: the Pack Discount (2nd/3rd pet on a lower
        # plan) is computed here and snapshotted on the Payment row — the client
        # never sends an amount. Exclude the pet being paid for so it can't anchor
        # the discount on itself; `code` limits the discount to a pet's FIRST
        # activation (upgrades and renewals pay full price).
        quote = pricing_utils.pack_discount_quote(
            db, member, plan, exclude_pet_id=pet.id, purchase_code=code
        )
        amount_php, discount_php = quote["final_php"], quote["discount_php"]
        line_item_name = f"MetroPaws {plan.name} Plan"
        if quote["discount_php"] > 0:
            line_item_name += f" ({quote['discount_percent']}% Pack Discount)"

    payment = models.Payment(
        member_id=member.id,
        plan_id=plan.id,
        pet_id=pet.id,
        amount_php=amount_php,
        discount_php=discount_php,
        subscription_id=subscription.id if subscription else None,
        status=models.PaymentStatus.pending,
    )
    db.add(payment)
    db.flush()

    try:
        session = await paymongo.create_checkout_session(
            line_item_name=line_item_name,
            amount_centavos=amount_php * 100,
            success_url=f"{success_base}?payment_id={payment.id}",
            cancel_url=f"{failure_base}?payment_id={payment.id}",
            reference_number=payment.id,
            metadata={
                "payment_id": payment.id,
                "member_id": member.id,
                "plan_id": plan.id,
                "pet_id": pet.id,
                "discount_php": str(discount_php),
                "cadence": payload.cadence,
            },
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=502, detail=f"Payment provider error: {e}") from e

    # Reuse provider_source_id to hold the Checkout Session id (cs_...) so no
    # DB migration is needed; the webhook matches the paid session by this id.
    payment.provider_source_id = session["id"]
    payment.checkout_url = session["attributes"]["checkout_url"]
    db.commit()
    db.refresh(payment)

    return schemas.CheckoutResponse(
        payment_id=payment.id,
        checkout_url=payment.checkout_url,
    )


# NOTE: like /quotes, must be declared BEFORE /{payment_id}.
@router.post("/installment", response_model=schemas.CheckoutResponse)
async def pay_installment(
    payload: schemas.InstallmentRequest,
    current_user: models.User = Depends(auth_utils.require_member),
    db: Session = Depends(get_db),
):
    """Pay the next monthly instalment on a pet's existing subscription.

    Member-initiated by necessity, and that turns out to be the thing that makes
    monthly workable at all: this backend has no scheduler to bill on a timer,
    and PayMongo has no saved card to bill while only QR Ph is active. Paying
    from the app needs neither. Reminders sit on top of this as an enhancement,
    not a prerequisite.

    Deliberately NOT /checkout: this is not a purchase. No upgrade or renewal
    eligibility is evaluated and no Pack Discount applies, because nothing is
    being bought — it is one payment against an arrangement that already exists.
    """
    if not get_payments_enabled(db):
        raise HTTPException(
            status_code=400, detail="Payments are currently disabled."
        )

    member = current_user.member
    if not member:
        raise HTTPException(status_code=400, detail="Member profile not found")

    pet = (
        db.query(models.Pet)
        .filter(models.Pet.id == payload.pet_id, models.Pet.member_id == member.id)
        .first()
    )
    if not pet:
        raise HTTPException(status_code=404, detail="Pet not found")

    subscription = subscription_utils.for_pet(db, pet)
    if subscription is None:
        raise HTTPException(
            status_code=404,
            detail=f"{pet.name} isn't on a monthly membership.",
        )

    plan = db.query(models.Plan).filter(models.Plan.id == subscription.plan_id).first()
    if not plan or not plan.price_monthly:
        raise HTTPException(
            status_code=400,
            detail="This plan no longer offers monthly instalments. Contact support.",
        )

    base_url = config.env("BASE_URL", "http://localhost:8000").rstrip("/")
    success_base = config.env("PAYMONGO_SUCCESS_REDIRECT", f"{base_url}/payments/return/success")
    failure_base = config.env("PAYMONGO_FAILURE_REDIRECT", f"{base_url}/payments/return/failed")

    payment = models.Payment(
        member_id=member.id,
        plan_id=plan.id,
        pet_id=pet.id,
        amount_php=plan.price_monthly,
        subscription_id=subscription.id,
        status=models.PaymentStatus.pending,
    )
    db.add(payment)
    db.flush()

    instalment_number = (subscription.consecutive_payments or 0) + 1
    try:
        session = await paymongo.create_checkout_session(
            line_item_name=f"MetroPaws {plan.name} Plan — instalment {instalment_number}",
            amount_centavos=plan.price_monthly * 100,
            success_url=f"{success_base}?payment_id={payment.id}",
            cancel_url=f"{failure_base}?payment_id={payment.id}",
            reference_number=payment.id,
            metadata={
                "payment_id": payment.id,
                "member_id": member.id,
                "plan_id": plan.id,
                "pet_id": pet.id,
                "subscription_id": subscription.id,
                "instalment": str(instalment_number),
            },
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=502, detail=f"Payment provider error: {e}") from e

    payment.provider_source_id = session["id"]
    payment.checkout_url = session["attributes"]["checkout_url"]
    db.commit()
    db.refresh(payment)

    return schemas.CheckoutResponse(
        payment_id=payment.id,
        checkout_url=payment.checkout_url,
    )


# NOTE: must be declared BEFORE /{payment_id} or "quotes" would be captured
# as a payment id by the dynamic route below.
@router.get("/quotes", response_model=list[schemas.PlanQuoteOut])
def get_plan_quotes(
    pet_id: str | None = None,
    current_user: models.User = Depends(auth_utils.require_member),
    db: Session = Depends(get_db),
):
    """Member-specific prices for every active plan, with the Pack Discount
    applied where eligible, plus upgrade/renewal eligibility for the given pet.
    The app displays these instead of computing any price or rule client-side.
    `pet_id` = the pet being (re)activated (excluded from the discount's anchor
    set; eligibility is computed against its current plan); omit it for a pet
    not yet created (Add-a-Pet flow — everything is 'new')."""
    member = current_user.member
    if not member:
        raise HTTPException(status_code=400, detail="Member profile not found")

    pet = None
    if pet_id:
        pet = (
            db.query(models.Pet)
            .filter(models.Pet.id == pet_id, models.Pet.member_id == member.id)
            .first()
        )
        if not pet:
            raise HTTPException(status_code=404, detail="Pet not found")

    plans = (
        db.query(models.Plan)
        .filter(models.Plan.is_active == True)
        .order_by(models.Plan.sort_order)
        .all()
    )
    quotes: list[schemas.PlanQuoteOut] = []
    for plan in plans:
        if pet is not None:
            allowed, code = plan_term_utils.purchase_eligibility(db, pet, plan)
        else:
            allowed, code = True, "new"
        quotes.append(
            schemas.PlanQuoteOut(
                plan_id=plan.id,
                eligible=allowed,
                eligibility=code,
                is_current=bool(pet is not None and pet.plan_id == plan.id),
                **pricing_utils.pack_discount_quote(
                    db, member, plan, exclude_pet_id=pet_id, purchase_code=code
                ),
            )
        )
    return quotes


@router.get("/{payment_id}", response_model=schemas.PaymentOut)
async def get_payment(
    payment_id: str,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    payment = (
        db.query(models.Payment).filter(models.Payment.id == payment_id).first()
    )
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if current_user.role == models.UserRole.member and (
        not current_user.member or payment.member_id != current_user.member.id
    ):
        raise HTTPException(status_code=403, detail="Forbidden")

    await _reconcile_pending_payment(db, payment, source="poll")
    return payment


async def _reconcile_pending_payment(
    db: Session, payment: models.Payment, *, source: str
) -> None:
    """Grant the plan inline if PayMongo confirms the checkout session is paid.

    The webhook is the normal grant path, but it can never arrive (e.g. the
    webhook points at a different environment) or time out on a sleepy host.
    This asks PayMongo directly and grants the plan when the session is paid, so
    a paid member is never left stuck. Idempotent — no-ops once the payment is
    already marked paid, and only ever grants when PayMongo says it's paid, so it
    is safe to call from unauthenticated entry points (the return page).
    """
    if payment.status != models.PaymentStatus.pending or not payment.provider_source_id:
        return
    try:
        session = await paymongo.retrieve_checkout_session(payment.provider_source_id)
        for p in session.get("attributes", {}).get("payments") or []:
            if p.get("attributes", {}).get("status") == "paid":
                payment.provider_payment_id = p.get("id")
                _grant_plan(db, payment)
                db.refresh(payment)
                logger.info(
                    "Reconciled payment %s via %s — plan granted", payment.id, source
                )
                break
    except Exception:
        # Keep status pending so other paths can still grant later, but never
        # swallow the reason silently — a paid member stuck with no plan is
        # invisible otherwise.
        db.rollback()
        logger.exception(
            "Reconcile failed for payment %s (source %s)",
            payment.id,
            payment.provider_source_id,
        )


async def reconcile_member_pending_payments(
    db: Session, member_id: str, *, source: str
) -> int:
    """Safety net: check this member's recent pending payments against PayMongo.

    Called on profile load (GET /members/me) so a paid-but-ungranted plan
    self-heals the next time the app fetches the dashboard, even when the
    webhook, the client poll, AND the return page all missed (observed
    2026-07-07: an Add-a-Pet checkout was paid on PayMongo but its payment row
    sat pending until manually reconciled). Bounded to recent payments so
    abandoned checkouts don't cost a provider call on every profile load
    forever. Returns the number of payments granted.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(days=7)
    pending = (
        db.query(models.Payment)
        .filter(
            models.Payment.member_id == member_id,
            models.Payment.status == models.PaymentStatus.pending,
            models.Payment.provider_source_id.isnot(None),
            models.Payment.created_at > cutoff,
        )
        .order_by(models.Payment.created_at.desc())
        .limit(5)
        .all()
    )
    granted = 0
    for payment in pending:
        await _reconcile_pending_payment(db, payment, source=source)
        if payment.status == models.PaymentStatus.paid:
            granted += 1
    return granted


def _deep_link_page(deep_link: str, heading: str, body: str) -> str:
    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MetroPaws · {heading}</title>
  <style>
    body{{font-family:sans-serif;display:flex;flex-direction:column;align-items:center;
          justify-content:center;min-height:100vh;margin:0;background:#f8f7f4;color:#1a1e32;padding:24px;box-sizing:border-box}}
    h2{{font-size:22px;margin-bottom:8px}}
    p{{color:#8b8fa8;font-size:15px;text-align:center;max-width:320px}}
    a{{display:inline-block;margin-top:24px;padding:14px 28px;background:#263258;color:#fff;
       border-radius:12px;text-decoration:none;font-size:15px;font-weight:600}}
  </style>
  <script>window.location.href = "{deep_link}";</script>
</head>
<body>
  <h2>{heading}</h2>
  <p>{body}</p>
  <a href="{deep_link}">Return to MetroPaws</a>
</body>
</html>"""


@router.get("/return/success", response_class=HTMLResponse)
async def payment_return_success(payment_id: str = "", db: Session = Depends(get_db)):
    # The browser is guaranteed to land here after a successful PayMongo payment,
    # so reconcile the grant here too. This is the reliable activation path when
    # the webhook never reaches this environment and the client poll doesn't run
    # (e.g. on web, where the timer is throttled in a backgrounded tab).
    if payment_id:
        payment = (
            db.query(models.Payment)
            .filter(models.Payment.id == payment_id)
            .first()
        )
        if payment:
            await _reconcile_pending_payment(db, payment, source="return_url")
    deep_link = f"metropaws://payment/success?payment_id={payment_id}"
    return HTMLResponse(_deep_link_page(
        deep_link=deep_link,
        heading="Payment successful!",
        body="Your plan is being activated. Tap below to return to the MetroPaws app.",
    ))


@router.get("/return/failed", response_class=HTMLResponse)
async def payment_return_failed(payment_id: str = ""):
    deep_link = f"metropaws://payment/failed?payment_id={payment_id}"
    return HTMLResponse(_deep_link_page(
        deep_link=deep_link,
        heading="Payment not completed",
        body="No charge was made. Tap below to return to the MetroPaws app and try again.",
    ))


@router.post("/webhook", status_code=200)
async def webhook(request: Request, db: Session = Depends(get_db)):
    raw = await request.body()
    sig = request.headers.get("paymongo-signature", "")
    if not paymongo.verify_webhook_signature(raw, sig):
        raise HTTPException(status_code=400, detail="Invalid signature")

    event = json.loads(raw)
    attributes = event.get("data", {}).get("attributes", {})
    event_type = attributes.get("type", "")
    resource = attributes.get("data", {})
    resource_attrs = resource.get("attributes", {})

    # Checkout Sessions charge automatically, so a single success event grants
    # the plan. The resource is the checkout_session; its id (cs_...) was stored
    # in provider_source_id at checkout time.
    if event_type == "checkout_session.payment.paid":
        session_id = resource.get("id")
        payment = (
            db.query(models.Payment)
            .filter(models.Payment.provider_source_id == session_id)
            .first()
        )
        if not payment:
            logger.warning(
                "Webhook paid event for unknown session %s — no matching payment",
                session_id,
            )
            return {"received": True}
        if payment.status == models.PaymentStatus.paid:
            return {"received": True}
        payments = resource_attrs.get("payments") or []
        if payments:
            payment.provider_payment_id = payments[0].get("id")
        _grant_plan(db, payment)
        logger.info("Webhook granted plan for payment %s", payment.id)
        return {"received": True}

    return {"received": True}


def _advance_subscription(
    db: Session, payment: models.Payment
) -> models.Subscription | None:
    """Count this payment against its monthly arrangement, if it belongs to one.

    Returns the subscription so the caller can tell an activating first
    installment (grant the plan) from every later one (do not). A payment with no
    `subscription_id` is an ordinary annual purchase and returns None.
    """
    if not payment.subscription_id:
        return None
    subscription = (
        db.query(models.Subscription)
        .filter(models.Subscription.id == payment.subscription_id)
        .first()
    )
    if subscription is None:
        return None

    paid_at = payment.paid_at or datetime.now(timezone.utc)
    subscription_utils.record_cleared_payment(subscription, paid_at.date())
    subscription.last_payment_at = paid_at
    db.flush()
    return subscription


def _grant_plan(db: Session, payment: models.Payment) -> None:
    from app.domain.paw_points_utils import award_points, has_awarded_for_reference

    # Already granted — do nothing. Four independent paths call this (webhook,
    # client poll, return page, profile reconcile) and each is supposed to check
    # that the payment is still pending first, but two of them CAN observe
    # 'pending' at the same moment and both proceed. Observed on dev 2026-08-17:
    # one ₱600 instalment ran the body twice, twelve seconds apart, and advanced
    # the vesting counter to 2 on a single payment.
    #
    # The PawPoints award survived that because it is keyed on payment.id; the
    # subscription counter was not, and neither is grant_plan_to_pet, which
    # rebuilds benefits and resets plan_activated_at every time it runs. This is
    # the one guard that makes the whole function idempotent rather than each
    # piece separately.
    if payment.status == models.PaymentStatus.paid:
        return

    member = (
        db.query(models.Member).filter(models.Member.id == payment.member_id).first()
    )
    plan = db.query(models.Plan).filter(models.Plan.id == payment.plan_id).first()
    if not member or not plan:
        return

    # A monthly installment AFTER the first must not re-grant. grant_plan_to_pet
    # deletes and rebuilds the pet's PetService rows and resets plan_activated_at,
    # which resets the wallet year with it — so re-granting every month would hand
    # a subscriber a fresh allowance twelve times a year. Installment one activates
    # the plan; the rest only advance the vesting counter, which
    # _advance_subscription has already done. They still get a receipt, because
    # money changed hands.
    subscription = _advance_subscription(db, payment)
    is_later_installment = subscription is not None and subscription.consecutive_payments > 1

    is_renewal = False
    if not is_later_installment:
        if payment.pet_id:
            from sqlalchemy.orm import joinedload
            pet = (
                db.query(models.Pet)
                .options(joinedload(models.Pet.pet_services).joinedload(models.PetService.service_type))
                .filter(models.Pet.id == payment.pet_id)
                .first()
            )
            if pet:
                is_renewal = pet.plan_activated_at is not None
                grant_plan_to_pet(db, pet, plan, member)
        else:
            is_renewal = member.plan_type is not None
            grant_plan_to_member(db, member, plan)

        # PawPoints mark joining or renewing a membership. An installment is
        # neither — it is one payment toward a membership that already exists.
        activity = "membership_renewal" if is_renewal else "membership_activation"
        if not has_awarded_for_reference(db, member.id, activity, payment.id):
            award_points(
                db,
                member_id=member.id,
                activity_type=activity,
                plan_type=plan.name,
                reference_id=payment.id,
                notes=f"Plan: {plan.name}",
            )

    payment.status = models.PaymentStatus.paid
    payment.paid_at = datetime.now(timezone.utc)
    db.commit()

    # Email the member their branded PDF receipt. Best-effort and never raises —
    # a mail hiccup must never undo a completed grant. Runs once per payment
    # because every caller (webhook / poll / return / safety-net) only reaches
    # _grant_plan while the payment is still pending.
    from app import invoice_utils
    invoice_utils.notify_payment_receipt(db, payment)
