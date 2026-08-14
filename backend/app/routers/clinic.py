from datetime import date as date_type
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from app.database import get_db
from app import models, schemas, auth as auth_utils

router = APIRouter(prefix="/clinic", tags=["clinic"])


def _get_clinic_bookings_for_member(db, member_id: str, clinic_id: str):
    return (
        db.query(models.Booking)
        .options(
            joinedload(models.Booking.member),
            joinedload(models.Booking.service_type),
        )
        .filter(
            models.Booking.member_id == member_id,
            models.Booking.clinic_id == clinic_id,
            models.Booking.status != models.BookingStatus.cancelled,
        )
        .order_by(models.Booking.booking_date, models.Booking.time_slot)
        .all()
    )


def _build_scan_result(member, pets, bookings):
    return schemas.ClinicScanResult(
        id=member.id,
        first_name=member.first_name,
        last_name=member.last_name,
        email=member.email,
        phone=member.phone,
        address=member.address,
        plan_type=member.plan_type,
        services=[schemas.MemberServiceOut.model_validate(s) for s in member.services],
        pets=[schemas.PetWithHistoryOut.model_validate(p) for p in pets],
        bookings=[schemas.ClinicBookingOut.model_validate(b) for b in bookings],
    )


@router.get("/scan/{qr_token}", response_model=schemas.ClinicScanResult)
def clinic_scan_qr(
    qr_token: str,
    current_user: models.User = Depends(auth_utils.require_clinic),
    db: Session = Depends(get_db),
):
    clinic = current_user.clinic_partner
    if not clinic:
        raise HTTPException(status_code=404, detail="Clinic partner record not found")

    # Try pet-level QR first (QR encodes pet.id)
    pet = (
        db.query(models.Pet)
        .options(
            joinedload(models.Pet.service_logs).joinedload(models.ServiceLog.service_type),
            joinedload(models.Pet.pet_services).joinedload(models.PetService.service_type),
        )
        .filter(models.Pet.id == qr_token)
        .first()
    )
    if pet:
        member = (
            db.query(models.Member)
            .options(
                joinedload(models.Member.user),
                joinedload(models.Member.services).joinedload(models.MemberService.service_type),
            )
            .filter(models.Member.id == pet.member_id)
            .first()
        )
        if not member:
            raise HTTPException(status_code=404, detail="Member not found for this QR token")
        pet.service_logs.sort(key=lambda log: log.logged_at, reverse=True)
        bookings = _get_clinic_bookings_for_member(db, member.id, clinic.id)
        return _build_scan_result(member, [pet], bookings)

    # Fall back to member-level QR (legacy / member's own QR token)
    member = (
        db.query(models.Member)
        .options(
            joinedload(models.Member.user),
            joinedload(models.Member.services).joinedload(models.MemberService.service_type),
            joinedload(models.Member.pets).options(
                joinedload(models.Pet.service_logs).joinedload(models.ServiceLog.service_type),
                joinedload(models.Pet.pet_services).joinedload(models.PetService.service_type),
            ),
        )
        .filter(models.Member.qr_token == qr_token)
        .first()
    )
    if not member:
        raise HTTPException(status_code=404, detail="Member not found for this QR token")

    for pet in member.pets:
        pet.service_logs.sort(key=lambda log: log.logged_at, reverse=True)

    bookings = _get_clinic_bookings_for_member(db, member.id, clinic.id)
    return _build_scan_result(member, member.pets, bookings)


@router.put("/bookings/{booking_id}/confirm", response_model=schemas.ClinicBookingOut)
def confirm_booking(
    booking_id: str,
    current_user: models.User = Depends(auth_utils.require_clinic),
    db: Session = Depends(get_db),
):
    clinic = current_user.clinic_partner
    if not clinic:
        raise HTTPException(status_code=404, detail="Clinic partner record not found")

    booking = (
        db.query(models.Booking)
        .options(
            joinedload(models.Booking.member),
            joinedload(models.Booking.service_type),
        )
        .filter(models.Booking.id == booking_id)
        .first()
    )
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.clinic_id != clinic.id:
        raise HTTPException(status_code=403, detail="This booking does not belong to your clinic")
    if booking.status != models.BookingStatus.pending:
        raise HTTPException(status_code=400, detail="Only pending bookings can be confirmed")

    # Deduct a session — prefer PetService, fall back to MemberService
    pet_service = (
        db.query(models.PetService)
        .join(models.Pet, models.Pet.id == models.PetService.pet_id)
        .filter(
            models.Pet.member_id == booking.member_id,
            models.PetService.service_type_id == booking.service_type_id,
            models.PetService.total_sessions > models.PetService.used_sessions,
        )
        .first()
    )
    member_service = None
    if not pet_service:
        member_service = (
            db.query(models.MemberService)
            .filter(
                models.MemberService.member_id == booking.member_id,
                models.MemberService.service_type_id == booking.service_type_id,
                models.MemberService.total_sessions > models.MemberService.used_sessions,
            )
            .first()
        )

    if pet_service:
        pet_service.used_sessions += 1
        booking.credit_used = True
    elif member_service:
        member_service.used_sessions += 1
        booking.credit_used = True

    booking.status = models.BookingStatus.confirmed
    db.commit()
    db.refresh(booking)
    return booking


@router.put("/bookings/{booking_id}/cancel", response_model=schemas.ClinicBookingOut)
def cancel_booking(
    booking_id: str,
    current_user: models.User = Depends(auth_utils.require_clinic),
    db: Session = Depends(get_db),
):
    clinic = current_user.clinic_partner
    if not clinic:
        raise HTTPException(status_code=404, detail="Clinic partner record not found")

    booking = (
        db.query(models.Booking)
        .options(
            joinedload(models.Booking.member),
            joinedload(models.Booking.service_type),
        )
        .filter(models.Booking.id == booking_id)
        .first()
    )
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.clinic_id != clinic.id:
        raise HTTPException(status_code=403, detail="This booking does not belong to your clinic")
    if booking.status == models.BookingStatus.cancelled:
        raise HTTPException(status_code=400, detail="Booking is already cancelled")

    # Restore credit if it was used
    if booking.credit_used:
        pet_service = (
            db.query(models.PetService)
            .join(models.Pet, models.Pet.id == models.PetService.pet_id)
            .filter(
                models.Pet.member_id == booking.member_id,
                models.PetService.service_type_id == booking.service_type_id,
                models.PetService.used_sessions > 0,
            )
            .first()
        )
        if pet_service:
            pet_service.used_sessions -= 1
        else:
            member_service = (
                db.query(models.MemberService)
                .filter(
                    models.MemberService.member_id == booking.member_id,
                    models.MemberService.service_type_id == booking.service_type_id,
                    models.MemberService.used_sessions > 0,
                )
                .first()
            )
            if member_service:
                member_service.used_sessions -= 1
        booking.credit_used = False

    booking.status = models.BookingStatus.cancelled
    db.commit()
    db.refresh(booking)
    return booking


@router.get("/bookings", response_model=list[schemas.ClinicBookingOut])
def list_clinic_bookings(
    date: Optional[str] = Query(None, description="Filter by date (YYYY-MM-DD)"),
    status: Optional[str] = Query(None, description="Filter by status: pending, confirmed, cancelled"),
    current_user: models.User = Depends(auth_utils.require_clinic),
    db: Session = Depends(get_db),
):
    clinic = current_user.clinic_partner
    if not clinic:
        raise HTTPException(status_code=404, detail="Clinic partner not found")

    query = (
        db.query(models.Booking)
        .options(
            joinedload(models.Booking.member),
            joinedload(models.Booking.service_type),
        )
        .filter(models.Booking.clinic_id == clinic.id)
    )

    if date:
        try:
            booking_date = date_type.fromisoformat(date)
            query = query.filter(models.Booking.booking_date == booking_date)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD.") from exc

    if status:
        query = query.filter(models.Booking.status == status)

    return query.order_by(
        models.Booking.booking_date,
        models.Booking.time_slot,
    ).all()
