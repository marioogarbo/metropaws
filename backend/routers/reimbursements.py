"""Member-facing reimbursement endpoints: submit a claim, list claims, resubmit
after a "needs info" request, and view the Benefit Wallet.

Admin review/approve/mark-paid live in routers/admin/reimbursements.py. See
docs/REIMBURSEMENT_FEATURE_PLAN.md.
"""
import hashlib
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session, joinedload

import config
from database import get_db
import models, schemas, auth as auth_utils
import plan_term_utils
import storage
import reimbursement_utils as rutils
from routers import settings as settings_router

router = APIRouter(prefix="/members/me", tags=["reimbursements"])

ALLOWED_RECEIPT_TYPES = {"image/jpeg", "image/png", "application/pdf"}
# Per-claim sanity ceiling (typo / abuse guard). Env is in pesos for readability.
MAX_CLAIM_CENTAVOS = config.env_int("REIMBURSEMENT_MAX_CLAIM_PHP", 20000) * 100
# Anti-spam: max claims a member can submit per rolling 24h.
MAX_CLAIMS_PER_DAY = config.env_int("REIMBURSEMENT_MAX_PER_DAY", 20)
# Grooming can be reimbursed at most once per this many days per pet (anti
# look-alike-pet fraud — mirrors the grooming booking 90-day return rule).
# Measured on the service date, so two grooming visits must be >= this far
# apart. Set to 0 to disable.
GROOMING_COOLDOWN_DAYS = config.env_int("REIMBURSEMENT_GROOMING_COOLDOWN_DAYS", 90)
# Categories treated as "grooming" for the cooldown above (case-insensitive).
_GROOMING_CATEGORY_NAMES = {"grooming", "full grooming"}
# Widest real timezone offset (UTC+14). Used to backstop the future-date check
# without depending on the member's specific timezone.
_MAX_TZ_OFFSET = timedelta(hours=14)
# How far ahead a payout_target=provider claim's appointment date may be — this
# is a pre-authorization request filed before the visit, not a completed-visit
# reimbursement, so it needs a forward-looking (not backward-looking) date rule.
PROVIDER_MAX_FUTURE_DAYS = config.env_int("REIMBURSEMENT_PROVIDER_MAX_FUTURE_DAYS", 60)


def _receipt_hash(upload: UploadFile) -> str:
    """SHA-256 of the upload's bytes (rewinds the stream so it can be re-read)."""
    raw = upload.file.read()
    upload.file.seek(0)
    return hashlib.sha256(raw).hexdigest()


def _get_member(current_user: models.User, db: Session) -> models.Member:
    member = db.query(models.Member).filter(models.Member.user_id == current_user.id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member profile not found")
    return member


def _validate_amount(claimed_amount_centavos: int) -> None:
    if claimed_amount_centavos <= 0:
        raise HTTPException(status_code=422, detail="Amount must be greater than zero.")
    if claimed_amount_centavos > MAX_CLAIM_CENTAVOS:
        raise HTTPException(
            status_code=422,
            detail=f"Amount exceeds the maximum claim of ₱{MAX_CLAIM_CENTAVOS // 100:,}.",
        )


def _validate_service_date(service_date: date, allow_future: bool = False) -> None:
    if not allow_future:
        # Member-target claims: the visit already happened and was already paid
        # for. The app's date picker already blocks future dates in the member's
        # OWN timezone (Manila for a PH phone). The server is a backstop only: it
        # rejects dates that are in the future EVERYWHERE on Earth — i.e. after
        # "today" at the earliest timezone (UTC+14). This never wrongly rejects a
        # member's legitimate local "today", whether they're in Manila or
        # travelling.
        latest_today_anywhere = (datetime.now(timezone.utc) + _MAX_TZ_OFFSET).date()
        if service_date > latest_today_anywhere:
            raise HTTPException(status_code=422, detail="Service date can't be in the future.")
        return

    # Provider-target claims: this is a pre-authorization request for an upcoming
    # appointment, so the direction flips — reject dates that are already in the
    # past everywhere on Earth (using the same UTC+14 backstop, mirrored), and cap
    # how far ahead it can be filed.
    earliest_today_anywhere = (datetime.now(timezone.utc) - _MAX_TZ_OFFSET).date()
    if service_date < earliest_today_anywhere:
        raise HTTPException(status_code=422, detail="Appointment date can't be in the past.")
    latest_allowed = earliest_today_anywhere + timedelta(days=PROVIDER_MAX_FUTURE_DAYS)
    if service_date > latest_allowed:
        raise HTTPException(
            status_code=422,
            detail=f"Appointment date can't be more than {PROVIDER_MAX_FUTURE_DAYS} days from now.",
        )


@router.post("/reimbursements", response_model=schemas.ReimbursementOut, status_code=201)
def submit_reimbursement(
    service_type_id: str = Form(...),
    pet_id: str = Form(...),
    provider_name: str = Form(...),
    service_date: date = Form(...),
    claimed_amount_centavos: int = Form(...),
    receipt_reference: str = Form(None),
    member_notes: str = Form(None),
    payout_target: str = Form("member"),
    provider_id: str = Form(None),
    receipt: UploadFile = File(...),
    current_user: models.User = Depends(auth_utils.require_member),
    db: Session = Depends(get_db),
):
    member = _get_member(current_user, db)

    if payout_target not in ("member", "provider"):
        raise HTTPException(status_code=422, detail="Invalid payout_target.")
    is_provider_target = payout_target == "provider"

    provider: models.ReimbursementProvider | None = None
    if is_provider_target:
        # Defense in depth — the mobile UI already hides this option when it
        # isn't available, but a claim must never be accepted from a stale
        # client. Resolves the member's override against the global switch, so a
        # restricted member is refused even while the feature is on for everyone
        # else. The message stays neutral either way: whether the member is
        # restricted is between MetroPaws and support, not an app error string.
        if not rutils.is_direct_pay_available(
            member, settings_router.get_direct_provider_payment_enabled(db)
        ):
            raise HTTPException(
                status_code=400,
                detail="Direct-to-provider payments aren't available right now.",
            )
        if not provider_id:
            raise HTTPException(status_code=422, detail="Select a provider to pay directly.")
        provider = (
            db.query(models.ReimbursementProvider)
            .filter(
                models.ReimbursementProvider.id == provider_id,
                models.ReimbursementProvider.is_active == True,
            )
            .first()
        )
        if not provider:
            raise HTTPException(status_code=404, detail="Provider not found or no longer available.")
        # Server-derived — ignore whatever free text the client sent for this path.
        provider_name = provider.name
    else:
        # Payout method must be on file BEFORE claiming — prevents the
        # "approved but nowhere to send the money" dead end. 'cash' needs no number.
        # Skipped for provider-target claims: the member is never the payee.
        has_payout = bool(member.payout_method) and (
            member.payout_method == "cash" or bool(member.payout_account_number)
        )
        if not has_payout:
            raise HTTPException(
                status_code=400,
                detail="Set up your payout method first (Account → Payout method) so we know where to send your reimbursement.",
            )

    # Anti-spam: rolling 24h submission cap.
    since = datetime.now(timezone.utc) - timedelta(hours=24)
    recent = (
        db.query(models.Reimbursement)
        .filter(
            models.Reimbursement.member_id == member.id,
            models.Reimbursement.created_at >= since,
        )
        .count()
    )
    if recent >= MAX_CLAIMS_PER_DAY:
        raise HTTPException(
            status_code=429,
            detail="You've submitted too many claims today. Please try again tomorrow.",
        )

    pet = (
        db.query(models.Pet)
        .filter(models.Pet.id == pet_id, models.Pet.member_id == member.id)
        .first()
    )
    if not pet:
        raise HTTPException(status_code=404, detail="Pet not found")
    if not pet.plan_id:
        raise HTTPException(
            status_code=400,
            detail="This pet doesn't have an active plan yet. Activate a plan before submitting a claim.",
        )
    # Plan expiry gate (2026-07-27): the benefit year ends 365 days after
    # activation — after that, new claims wait for a renewal. Resubmits of
    # in-term claims are deliberately NOT gated (see resubmit endpoint).
    if plan_term_utils.plan_status(pet) == "expired":
        raise HTTPException(
            status_code=400,
            detail=(
                f"{pet.name}'s plan year has ended — renew the plan to keep "
                "using benefits."
            ),
        )

    service_type = (
        db.query(models.ServiceType).filter(models.ServiceType.id == service_type_id).first()
    )
    if not service_type:
        raise HTTPException(status_code=404, detail="Service type not found")

    if is_provider_target and not rutils.is_direct_pay_eligible_category(service_type.name):
        raise HTTPException(
            status_code=400,
            detail="This service category can't be paid directly to a provider — submit a reimbursement claim instead.",
        )

    # The claim draws from one of two pools, decided by its service category:
    # "Emergency" → Emergency Wallet, anything else → Preventive Wellness Wallet.
    emergency = rutils.is_emergency_category(service_type.name)
    wallet_name = "Emergency Wallet" if emergency else "Preventive Wellness Wallet"
    wallet = (
        rutils.plan_emergency_wallet_centavos(db, pet.plan_id)
        if emergency
        else rutils.plan_wallet_centavos(db, pet.plan_id)
    )
    if wallet <= 0:
        raise HTTPException(
            status_code=400,
            detail=f"Your plan doesn't include a {wallet_name}.",
        )

    _validate_amount(claimed_amount_centavos)
    _validate_service_date(service_date, allow_future=is_provider_target)

    # A provider-target claim books a FUTURE appointment — it can't be scheduled
    # past the plan year's end (the benefit funding it would have expired).
    if is_provider_target:
        term = plan_term_utils.plan_term(pet)
        if term is not None and service_date > term[1].date():
            raise HTTPException(
                status_code=400,
                detail=(
                    "That appointment date is after the plan year ends — renew "
                    "the plan first, or pick an earlier date."
                ),
            )

    # Insufficient balance: the claim (plus claims still awaiting a decision) in
    # the SAME pool can't exceed what's left in that pool this plan year.
    prev_used, prev_pending, emg_used, emg_pending = rutils.wallet_usage(db, pet)
    used, pending = (emg_used, emg_pending) if emergency else (prev_used, prev_pending)
    remaining = wallet - used - pending
    if claimed_amount_centavos > remaining:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Insufficient wallet balance — ₱{max(0, remaining) / 100:,.2f} "
                f"left in {pet.name}'s {wallet_name}."
            ),
        )

    # No duplicate claims (same provider + date + amount, unless previously rejected).
    duplicate = (
        db.query(models.Reimbursement)
        .filter(
            models.Reimbursement.member_id == member.id,
            models.Reimbursement.provider_name == provider_name,
            models.Reimbursement.service_date == service_date,
            models.Reimbursement.claimed_amount_centavos == claimed_amount_centavos,
            models.Reimbursement.status != models.ReimbursementStatus.rejected,
        )
        .first()
    )
    if duplicate:
        raise HTTPException(
            status_code=409,
            detail="A matching claim already exists. The same transaction can't be claimed twice.",
        )

    # Grooming cooldown: one grooming reimbursement per pet per
    # GROOMING_COOLDOWN_DAYS window. Grooming visits closer together than that
    # can't both be reimbursed (anti look-alike-pet fraud).
    if (
        GROOMING_COOLDOWN_DAYS > 0
        and service_type.name.strip().lower() in _GROOMING_CATEGORY_NAMES
    ):
        window = timedelta(days=GROOMING_COOLDOWN_DAYS)
        # Match ANY grooming-named category, not just the exact one picked — a
        # claim filed under "Full Grooming" still blocks one under "Grooming".
        grooming_type_ids = [
            st.id
            for st in db.query(models.ServiceType).all()
            if (st.name or "").strip().lower() in _GROOMING_CATEGORY_NAMES
        ]
        recent_grooming = (
            db.query(models.Reimbursement)
            .filter(
                models.Reimbursement.pet_id == pet.id,
                models.Reimbursement.service_type_id.in_(grooming_type_ids),
                models.Reimbursement.status != models.ReimbursementStatus.rejected,
                models.Reimbursement.service_date > service_date - window,
                models.Reimbursement.service_date < service_date + window,
            )
            .order_by(models.Reimbursement.service_date.desc())
            .first()
        )
        if recent_grooming:
            raise HTTPException(
                status_code=409,
                detail=(
                    f"Grooming can only be reimbursed once every {GROOMING_COOLDOWN_DAYS} days. "
                    f"There's already a grooming claim for {pet.name} dated "
                    f"{recent_grooming.service_date:%b %d, %Y}."
                ),
            )

    # Fraud guard: reject a receipt file that was already submitted (even by
    # another member) unless that prior claim was rejected.
    receipt_hash = _receipt_hash(receipt)
    reused = (
        db.query(models.Reimbursement)
        .filter(
            models.Reimbursement.receipt_sha256 == receipt_hash,
            models.Reimbursement.status != models.ReimbursementStatus.rejected,
        )
        .first()
    )
    if reused:
        raise HTTPException(
            status_code=409,
            detail="This exact receipt has already been submitted.",
        )

    receipt_url = storage.save_upload(receipt, "receipts", ALLOWED_RECEIPT_TYPES)

    claim = models.Reimbursement(
        member_id=member.id,
        pet_id=pet.id,
        service_type_id=service_type_id,
        provider_name=provider_name,
        service_date=service_date,
        claimed_amount_centavos=claimed_amount_centavos,
        receipt_url=receipt_url,
        receipt_reference=receipt_reference,
        receipt_sha256=receipt_hash,
        member_notes=member_notes,
        status=models.ReimbursementStatus.pending,
        payout_target=models.PayoutTarget.provider if is_provider_target else models.PayoutTarget.member,
        provider_id=provider.id if provider else None,
    )
    db.add(claim)
    db.flush()
    db.add(
        models.ReimbursementEvent(
            reimbursement_id=claim.id,
            from_status=None,
            to_status=models.ReimbursementStatus.pending.value,
            actor_user_id=current_user.id,
            note="Claim submitted",
        )
    )
    db.commit()
    db.refresh(claim)
    return claim


@router.get("/reimbursements", response_model=list[schemas.ReimbursementOut])
def list_my_reimbursements(
    current_user: models.User = Depends(auth_utils.require_member),
    db: Session = Depends(get_db),
):
    member = _get_member(current_user, db)
    return (
        db.query(models.Reimbursement)
        .options(joinedload(models.Reimbursement.service_type))
        .filter(models.Reimbursement.member_id == member.id)
        .order_by(models.Reimbursement.created_at.desc())
        .all()
    )


@router.post("/reimbursements/{reimbursement_id}/resubmit", response_model=schemas.ReimbursementOut)
def resubmit_reimbursement(
    reimbursement_id: str,
    provider_name: str = Form(None),
    service_date: date = Form(None),
    claimed_amount_centavos: int = Form(None),
    member_notes: str = Form(None),
    receipt: UploadFile = File(None),
    current_user: models.User = Depends(auth_utils.require_member),
    db: Session = Depends(get_db),
):
    """Re-upload a clearer/corrected receipt to a claim the admin marked
    ``needs_info``. Returns the claim to ``under_review``."""
    member = _get_member(current_user, db)
    claim = (
        db.query(models.Reimbursement)
        .filter(
            models.Reimbursement.id == reimbursement_id,
            models.Reimbursement.member_id == member.id,
        )
        .first()
    )
    if not claim:
        raise HTTPException(status_code=404, detail="Claim not found")
    if claim.status != models.ReimbursementStatus.needs_info:
        raise HTTPException(
            status_code=400,
            detail="Only claims that need more information can be resubmitted.",
        )

    if receipt and receipt.filename:
        claim.receipt_sha256 = _receipt_hash(receipt)
        claim.receipt_url = storage.save_upload(receipt, "receipts", ALLOWED_RECEIPT_TYPES)
    if provider_name is not None:
        claim.provider_name = provider_name
    if service_date is not None:
        _validate_service_date(service_date)
        claim.service_date = service_date
    if claimed_amount_centavos is not None:
        _validate_amount(claimed_amount_centavos)
        # Re-check the wallet: the member may raise the amount on resubmit. Check
        # against the pool this claim's category draws from.
        pet = db.query(models.Pet).filter(models.Pet.id == claim.pet_id).first()
        if pet is not None:
            emergency = rutils.is_emergency_category(
                claim.service_type.name if claim.service_type else None
            )
            wallet_name = "Emergency Wallet" if emergency else "Preventive Wellness Wallet"
            wallet = (
                rutils.plan_emergency_wallet_centavos(db, pet.plan_id)
                if emergency
                else rutils.plan_wallet_centavos(db, pet.plan_id)
            )
            prev_used, prev_pending, emg_used, emg_pending = rutils.wallet_usage(
                db, pet, exclude_id=claim.id
            )
            used, pending = (
                (emg_used, emg_pending) if emergency else (prev_used, prev_pending)
            )
            remaining = wallet - used - pending
            if claimed_amount_centavos > remaining:
                raise HTTPException(
                    status_code=400,
                    detail=(
                        f"Insufficient wallet balance — ₱{max(0, remaining) / 100:,.2f} "
                        f"left in {pet.name}'s {wallet_name}."
                    ),
                )
        claim.claimed_amount_centavos = claimed_amount_centavos
    if member_notes is not None:
        claim.member_notes = member_notes

    prev = claim.status
    claim.status = models.ReimbursementStatus.under_review
    db.add(
        models.ReimbursementEvent(
            reimbursement_id=claim.id,
            from_status=prev.value,
            to_status=models.ReimbursementStatus.under_review.value,
            actor_user_id=current_user.id,
            note="Resubmitted by member",
        )
    )
    db.commit()
    db.refresh(claim)
    return claim


@router.get("/wallet", response_model=schemas.WalletOut)
def get_wallet(
    current_user: models.User = Depends(auth_utils.require_member),
    db: Session = Depends(get_db),
):
    """Benefit Wallet: TWO pools per pet (from the pet's plan) — the Preventive
    Wellness Wallet (non-emergency claims) and the Emergency Wallet ("Emergency"
    category claims) — plus the service categories a claim can be filed under.
    The category is a label that also picks the pool (and grooming drives the
    90-day cooldown). Amounts in centavos. Pets whose plan has neither wallet are
    omitted."""
    member = _get_member(current_user, db)
    pets = (
        db.query(models.Pet)
        .filter(models.Pet.member_id == member.id, models.Pet.plan_id.isnot(None))
        .all()
    )

    wallet_pets: list[schemas.WalletPetOut] = []
    for pet in pets:
        wallet = rutils.plan_wallet_centavos(db, pet.plan_id)
        emergency_wallet = rutils.plan_emergency_wallet_centavos(db, pet.plan_id)
        if wallet <= 0 and emergency_wallet <= 0:
            continue
        prev_used, prev_pending, emg_used, emg_pending = rutils.wallet_usage(db, pet)
        term = plan_term_utils.plan_term(pet)
        wallet_pets.append(
            schemas.WalletPetOut(
                pet_id=pet.id,
                pet_name=pet.name,
                wallet_centavos=wallet,
                pending_centavos=prev_pending,
                used_centavos=prev_used,
                remaining_centavos=max(0, wallet - prev_used - prev_pending),
                emergency_wallet_centavos=emergency_wallet,
                emergency_pending_centavos=emg_pending,
                emergency_used_centavos=emg_used,
                emergency_remaining_centavos=max(0, emergency_wallet - emg_used - emg_pending),
                plan_status=plan_term_utils.plan_status(pet),
                plan_expires_at=term[1] if term else None,
            )
        )

    service_types = (
        db.query(models.ServiceType).order_by(models.ServiceType.name).all()
    )
    return schemas.WalletOut(
        pets=wallet_pets,
        service_types=[
            schemas.ServiceTypeOut.model_validate(st) for st in service_types
        ],
        # Member-scoped, unlike /settings/mobile-config — that endpoint is
        # unauthenticated and can only ever carry the global switch. This is the
        # value the app should gate the direct-pay option on.
        direct_pay_available=rutils.is_direct_pay_available(
            member, settings_router.get_direct_provider_payment_enabled(db)
        ),
    )
