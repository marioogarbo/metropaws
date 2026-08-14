"""Booking review — confirm or cancel a member's requested appointment,
moving the session credit with it."""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload

import models, schemas, auth as auth_utils
from database import get_db

router = APIRouter(tags=["admin"])


@router.get("/bookings", response_model=list[schemas.AdminBookingOut])
def list_bookings(
    status: Optional[str] = Query(None),
    skip: int = 0,
    limit: int = 100,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    q = (
        db.query(models.Booking)
        .options(
            joinedload(models.Booking.service_type),
            joinedload(models.Booking.member),
            joinedload(models.Booking.clinic),
        )
    )
    if status:
        try:
            q = q.filter(models.Booking.status == models.BookingStatus(status))
        except ValueError as exc:
            raise HTTPException(status_code=400, detail="Invalid status value") from exc
    return (
        q.order_by(models.Booking.booking_date.asc(), models.Booking.created_at.asc())
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.put("/bookings/{booking_id}/confirm", response_model=schemas.AdminBookingOut)
def confirm_booking(
    booking_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    booking = (
        db.query(models.Booking)
        .options(
            joinedload(models.Booking.service_type),
            joinedload(models.Booking.member),
            joinedload(models.Booking.clinic),
        )
        .filter(models.Booking.id == booking_id)
        .first()
    )
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.status != models.BookingStatus.pending:
        raise HTTPException(status_code=400, detail="Only pending bookings can be confirmed")

    # Deduct a session if the member now has credit (e.g. after payment)
    member_service = db.query(models.MemberService).filter(
        models.MemberService.member_id == booking.member_id,
        models.MemberService.service_type_id == booking.service_type_id,
    ).first()
    if member_service and member_service.remaining_sessions > 0:
        member_service.used_sessions += 1
        booking.credit_used = True

    booking.status = models.BookingStatus.confirmed
    db.commit()
    db.refresh(booking)
    return booking


@router.put("/bookings/{booking_id}/cancel", response_model=schemas.AdminBookingOut)
def cancel_booking(
    booking_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    booking = (
        db.query(models.Booking)
        .options(
            joinedload(models.Booking.service_type),
            joinedload(models.Booking.member),
            joinedload(models.Booking.clinic),
        )
        .filter(models.Booking.id == booking_id)
        .first()
    )
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.status == models.BookingStatus.cancelled:
        raise HTTPException(status_code=400, detail="Booking is already cancelled")

    # Restore session credit if it was used
    if booking.credit_used:
        member_service = db.query(models.MemberService).filter(
            models.MemberService.member_id == booking.member_id,
            models.MemberService.service_type_id == booking.service_type_id,
        ).first()
        if member_service and member_service.used_sessions > 0:
            member_service.used_sessions -= 1
        booking.credit_used = False

    booking.status = models.BookingStatus.cancelled
    db.commit()
    db.refresh(booking)
    return booking
