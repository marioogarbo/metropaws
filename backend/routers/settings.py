from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import auth as auth_utils
import models
import schemas
from database import get_db
from domain.pricing_utils import (
    PACK_DISCOUNT_ENABLED_KEY,
    PACK_DISCOUNT_PERCENT_KEY,
    pack_discount_settings,
)

router = APIRouter(tags=["settings"])

PAYMENTS_ENABLED_KEY = "payments_enabled"
FOUNDING_50_ENABLED_KEY = "founding_50_enabled"
FOUNDING_50_LIMIT_KEY = "founding_50_limit"
# Booking/sessions are on standby until partner clinics exist (client decision
# 2026-07-09). Default false — flipping this row re-shows the mobile Book tab
# without an app release.
BOOKING_ENABLED_KEY = "booking_enabled"
# Kill-switch for the "MetroPaws pays the provider directly" reimbursement
# option (scheduled/non-emergency categories only — see
# reimbursement_utils.is_direct_pay_eligible_category). Default false until
# admin explicitly turns it on.
DIRECT_PROVIDER_PAYMENT_ENABLED_KEY = "direct_provider_payment_enabled"


def get_booking_enabled(db: Session) -> bool:
    row = db.query(models.AppSetting).filter(
        models.AppSetting.key == BOOKING_ENABLED_KEY
    ).first()
    return row.value == "true" if row else False


def get_direct_provider_payment_enabled(db: Session) -> bool:
    row = db.query(models.AppSetting).filter(
        models.AppSetting.key == DIRECT_PROVIDER_PAYMENT_ENABLED_KEY
    ).first()
    return row.value == "true" if row else False


def get_payments_enabled(db: Session) -> bool:
    row = db.query(models.AppSetting).filter(
        models.AppSetting.key == PAYMENTS_ENABLED_KEY
    ).first()
    return row.value == "true" if row else True


def get_founding_50_enabled(db: Session) -> bool:
    row = db.query(models.AppSetting).filter(
        models.AppSetting.key == FOUNDING_50_ENABLED_KEY
    ).first()
    return row.value == "true" if row else True


def get_founding_50_limit(db: Session) -> int:
    row = db.query(models.AppSetting).filter(
        models.AppSetting.key == FOUNDING_50_LIMIT_KEY
    ).first()
    return int(row.value) if row else 50


def get_founding_50_claimed(db: Session) -> int:
    return db.query(models.Member).filter(models.Member.is_founding == True).count()


@router.get("/settings/payments-enabled", response_model=schemas.PaymentsEnabledOut)
def read_payments_enabled(db: Session = Depends(get_db)):
    return {"payments_enabled": get_payments_enabled(db)}


@router.put(
    "/admin/settings/payments-enabled",
    response_model=schemas.PaymentsEnabledOut,
)
def update_payments_enabled(
    payload: schemas.PaymentsEnabledUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    row = db.query(models.AppSetting).filter(
        models.AppSetting.key == PAYMENTS_ENABLED_KEY
    ).first()
    new_value = "true" if payload.payments_enabled else "false"
    if row:
        row.value = new_value
    else:
        db.add(models.AppSetting(key=PAYMENTS_ENABLED_KEY, value=new_value))
    db.commit()
    return {"payments_enabled": payload.payments_enabled}


@router.get("/settings/mobile-config", response_model=schemas.MobileConfigOut)
def read_mobile_config(db: Session = Depends(get_db)):
    """Feature flags the mobile app reads at startup."""
    return {
        "booking_enabled": get_booking_enabled(db),
        "direct_provider_payment_enabled": get_direct_provider_payment_enabled(db),
    }


@router.put(
    "/admin/settings/booking-enabled",
    response_model=schemas.MobileConfigOut,
)
def update_booking_enabled(
    payload: schemas.BookingEnabledUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    row = db.query(models.AppSetting).filter(
        models.AppSetting.key == BOOKING_ENABLED_KEY
    ).first()
    new_value = "true" if payload.booking_enabled else "false"
    if row:
        row.value = new_value
    else:
        db.add(models.AppSetting(key=BOOKING_ENABLED_KEY, value=new_value))
    db.commit()
    return {
        "booking_enabled": payload.booking_enabled,
        "direct_provider_payment_enabled": get_direct_provider_payment_enabled(db),
    }


@router.put(
    "/admin/settings/direct-provider-payment",
    response_model=schemas.MobileConfigOut,
)
def update_direct_provider_payment_enabled(
    payload: schemas.DirectProviderPaymentUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    row = db.query(models.AppSetting).filter(
        models.AppSetting.key == DIRECT_PROVIDER_PAYMENT_ENABLED_KEY
    ).first()
    new_value = "true" if payload.direct_provider_payment_enabled else "false"
    if row:
        row.value = new_value
    else:
        db.add(models.AppSetting(key=DIRECT_PROVIDER_PAYMENT_ENABLED_KEY, value=new_value))
    db.commit()
    return {
        "booking_enabled": get_booking_enabled(db),
        "direct_provider_payment_enabled": payload.direct_provider_payment_enabled,
    }


@router.get("/settings/founding-50", response_model=schemas.Founding50Out)
def read_founding_50(db: Session = Depends(get_db)):
    return schemas.Founding50Out(
        enabled=get_founding_50_enabled(db),
        limit=get_founding_50_limit(db),
        claimed=get_founding_50_claimed(db),
    )


@router.get("/settings/pack-discount", response_model=schemas.PackDiscountOut)
def read_pack_discount(db: Session = Depends(get_db)):
    """Current multi-pet Pack Discount settings (see pricing_utils.py — the
    ONLY place the discount rule and its price math live). Public: the same
    information is already implied by /payments/quotes and the marketing FAQ."""
    enabled, percent = pack_discount_settings(db)
    return {"enabled": enabled, "percent": percent}


@router.put("/admin/settings/pack-discount", response_model=schemas.PackDiscountOut)
def update_pack_discount(
    payload: schemas.PackDiscountUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    for key, val in [
        (PACK_DISCOUNT_ENABLED_KEY, "true" if payload.enabled else "false"),
        (PACK_DISCOUNT_PERCENT_KEY, str(payload.percent)),
    ]:
        row = db.query(models.AppSetting).filter(models.AppSetting.key == key).first()
        if row:
            row.value = val
        else:
            db.add(models.AppSetting(key=key, value=val))
    db.commit()
    return {"enabled": payload.enabled, "percent": payload.percent}


@router.put("/admin/settings/founding-50", response_model=schemas.Founding50Out)
def update_founding_50(
    payload: schemas.Founding50Update,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    claimed = get_founding_50_claimed(db)
    if payload.enabled and claimed >= payload.limit:
        raise HTTPException(
            status_code=400,
            detail=f"All {payload.limit} founding spots are already claimed. Increase the limit before re-enabling enrollment.",
        )
    for key, val in [
        (FOUNDING_50_ENABLED_KEY, "true" if payload.enabled else "false"),
        (FOUNDING_50_LIMIT_KEY, str(payload.limit)),
    ]:
        row = db.query(models.AppSetting).filter(models.AppSetting.key == key).first()
        if row:
            row.value = val
        else:
            db.add(models.AppSetting(key=key, value=val))
    db.commit()
    return schemas.Founding50Out(
        enabled=payload.enabled,
        limit=payload.limit,
        claimed=claimed,
    )
