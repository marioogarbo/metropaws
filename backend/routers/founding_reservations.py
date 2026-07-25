from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from database import get_db
import models, schemas, auth as auth_utils

public_router = APIRouter(tags=["founding-reservations"])
admin_router = APIRouter(prefix="/admin", tags=["admin"])


@public_router.post("/founding-reservations", status_code=201)
def submit_reservation(
    payload: schemas.FoundingReservationCreate,
    db: Session = Depends(get_db),
):
    duplicate = (
        db.query(models.FoundingReservation)
        .filter(models.FoundingReservation.email == payload.email)
        .first()
    )
    if duplicate:
        raise HTTPException(status_code=409, detail="This email has already been submitted.")

    reservation = models.FoundingReservation(**payload.model_dump())
    db.add(reservation)
    db.commit()
    db.refresh(reservation)
    return {"id": reservation.id, "message": "Reservation received. We'll be in touch!"}


@admin_router.get("/founding-reservations", response_model=List[schemas.FoundingReservationOut])
def list_reservations(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.FoundingReservation)
        .order_by(models.FoundingReservation.created_at.desc())
        .all()
    )


@admin_router.put(
    "/founding-reservations/{reservation_id}/status",
    response_model=schemas.FoundingReservationOut,
)
def update_reservation_status(
    reservation_id: str,
    payload: schemas.FoundingReservationStatusUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    reservation = (
        db.query(models.FoundingReservation)
        .filter(models.FoundingReservation.id == reservation_id)
        .first()
    )
    if not reservation:
        raise HTTPException(status_code=404, detail="Reservation not found")

    valid_statuses = {"pending", "approved", "rejected"}
    if payload.status not in valid_statuses:
        raise HTTPException(status_code=422, detail=f"Status must be one of {valid_statuses}")

    reservation.status = payload.status
    if payload.admin_notes is not None:
        reservation.admin_notes = payload.admin_notes
    db.commit()
    db.refresh(reservation)
    return reservation


@admin_router.delete("/founding-reservations/{reservation_id}", status_code=204)
def delete_reservation(
    reservation_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    reservation = (
        db.query(models.FoundingReservation)
        .filter(models.FoundingReservation.id == reservation_id)
        .first()
    )
    if not reservation:
        raise HTTPException(status_code=404, detail="Reservation not found")

    db.delete(reservation)
    db.commit()
