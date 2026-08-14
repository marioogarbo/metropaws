from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session, joinedload
from database import get_db
import models, schemas, auth as auth_utils
import storage
from routers.payments import reconcile_member_pending_payments
import asyncio
import logging
import qrcode
import io
import config

logger = logging.getLogger("metropaws.members")

router = APIRouter(prefix="/members", tags=["members"])

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


@router.get("/clinics", response_model=list[schemas.ClinicBriefOut])
def list_clinics(db: Session = Depends(get_db)):
    return db.query(models.ClinicPartner).order_by(models.ClinicPartner.clinic_name).all()


@router.get("/reimbursement-providers", response_model=list[schemas.ReimbursementProviderBriefOut])
def list_reimbursement_providers(db: Session = Depends(get_db)):
    """Verified direct-pay providers for the "pay the provider directly" claim
    option (see routers/reimbursements.py). Active only; payout details are never
    exposed here — only in the admin-facing ReimbursementProviderOut shape."""
    return (
        db.query(models.ReimbursementProvider)
        .filter(models.ReimbursementProvider.is_active == True)
        .order_by(models.ReimbursementProvider.name)
        .all()
    )

BASE_URL = config.env("BASE_URL", "http://localhost:8000")


@router.get("/me", response_model=schemas.MemberOut)
async def get_my_profile(
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = (
        db.query(models.Member)
        .options(
            joinedload(models.Member.pets),
            joinedload(models.Member.services).joinedload(models.MemberService.service_type),
        )
        .filter(models.Member.user_id == current_user.id)
        .first()
    )
    if not member:
        raise HTTPException(status_code=404, detail="Member profile not found")
    # Payment safety net: if a recent checkout was paid on PayMongo but never
    # granted (webhook missed the env + return page never landed + app didn't
    # poll), heal it here — the dashboard profile load is the one call every
    # member makes. Granting commits, which expires `member`, so the response
    # serializes the freshly activated plan. Never block profile load on the
    # payment provider.
    try:
        # Bound it: this best-effort safety net must NEVER slow the profile
        # load. A member with several stale pending checkouts would otherwise
        # serialize multiple PayMongo calls (up to 30s each) into a multi-minute
        # hang on /members/me. The webhook, the client poll, and the NEXT
        # profile load remain as reconciliation paths, so cutting it short is
        # safe (asyncio.TimeoutError is an Exception, so it's caught below).
        await asyncio.wait_for(
            reconcile_member_pending_payments(db, member.id, source="profile_load"),
            timeout=8.0,
        )
    except Exception:
        logger.exception("Pending-payment reconcile skipped/failed during profile load")
    return member


@router.put("/me", response_model=schemas.MemberOut)
def update_my_profile(
    payload: schemas.MemberUpdate,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = db.query(models.Member).filter(models.Member.user_id == current_user.id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member profile not found")
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(member, field, value)
    db.commit()
    db.refresh(member)
    return member


@router.post("/me/photo", response_model=schemas.MemberOut)
def upload_my_photo(
    photo: UploadFile = File(...),
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = db.query(models.Member).filter(models.Member.user_id == current_user.id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member profile not found")
    member.photo_url = storage.save_upload(photo, "photos", ALLOWED_IMAGE_TYPES)
    db.commit()
    db.refresh(member)
    return member


@router.get("/me/qr")
def get_my_qr_code(
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = db.query(models.Member).filter(models.Member.user_id == current_user.id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")

    qr_data = f"{BASE_URL}/admin/scan/{member.qr_token}"
    img = qrcode.make(qr_data)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    return StreamingResponse(buf, media_type="image/png")


@router.get("/me/services", response_model=list[schemas.MemberServiceOut])
def get_my_services(
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = db.query(models.Member).filter(models.Member.user_id == current_user.id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    return (
        db.query(models.MemberService)
        .options(joinedload(models.MemberService.service_type))
        .filter(models.MemberService.member_id == member.id)
        .all()
    )


@router.post("/me/plan", status_code=410)
def select_plan_deprecated():
    raise HTTPException(
        status_code=410,
        detail="Plans are now activated per pet. Use POST /pets/{pet_id}/activate-plan instead.",
    )


@router.post("/me/bookings", response_model=schemas.BookingOut, status_code=201)
def create_booking(
    payload: schemas.BookingCreate,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = db.query(models.Member).filter(models.Member.user_id == current_user.id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")

    service_type = db.query(models.ServiceType).filter(
        models.ServiceType.id == payload.service_type_id
    ).first()
    if not service_type:
        raise HTTPException(status_code=404, detail="Service type not found")

    clinic = db.query(models.ClinicPartner).filter(
        models.ClinicPartner.id == payload.clinic_id
    ).first()
    if not clinic:
        raise HTTPException(status_code=404, detail="Clinic not found")

    # Always create as pending — the partner clinic confirms and deducts credit
    booking = models.Booking(
        member_id=member.id,
        service_type_id=payload.service_type_id,
        clinic_id=payload.clinic_id,
        booking_date=payload.booking_date,
        time_slot=payload.time_slot,
        notes=payload.notes,
        status=models.BookingStatus.pending,
        credit_used=False,
    )

    db.add(booking)
    db.commit()
    db.refresh(booking)
    return booking


# --- In-app notifications (bell icon) ---

def _get_member_or_404(current_user: models.User, db: Session) -> models.Member:
    member = db.query(models.Member).filter(models.Member.user_id == current_user.id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    return member


@router.get("/me/notifications", response_model=list[schemas.NotificationOut])
def get_my_notifications(
    limit: int = 50,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = _get_member_or_404(current_user, db)
    return (
        db.query(models.Notification)
        .filter(models.Notification.member_id == member.id)
        .order_by(models.Notification.created_at.desc())
        .limit(min(limit, 100))
        .all()
    )


@router.get("/me/notifications/unread-count")
def get_my_unread_count(
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = _get_member_or_404(current_user, db)
    unread = (
        db.query(models.Notification)
        .filter(
            models.Notification.member_id == member.id,
            models.Notification.is_read == False,  # noqa: E712
        )
        .count()
    )
    return {"unread": unread}


@router.put("/me/notifications/{notification_id}/read", response_model=schemas.NotificationOut)
def mark_notification_read(
    notification_id: str,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = _get_member_or_404(current_user, db)
    notif = (
        db.query(models.Notification)
        .filter(
            models.Notification.id == notification_id,
            models.Notification.member_id == member.id,
        )
        .first()
    )
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    notif.is_read = True
    db.commit()
    db.refresh(notif)
    return notif


@router.put("/me/notifications/read-all", status_code=204)
def mark_all_notifications_read(
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = _get_member_or_404(current_user, db)
    db.query(models.Notification).filter(
        models.Notification.member_id == member.id,
        models.Notification.is_read == False,  # noqa: E712
    ).update({models.Notification.is_read: True}, synchronize_session=False)
    db.commit()


@router.get("/me/bookings", response_model=list[schemas.BookingOut])
def get_my_bookings(
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = db.query(models.Member).filter(models.Member.user_id == current_user.id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    return (
        db.query(models.Booking)
        .options(
            joinedload(models.Booking.service_type),
            joinedload(models.Booking.clinic),
        )
        .filter(models.Booking.member_id == member.id)
        .order_by(models.Booking.booking_date.desc(), models.Booking.created_at.desc())
        .all()
    )
