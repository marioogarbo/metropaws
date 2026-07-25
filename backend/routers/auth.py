from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from database import get_db
import models, schemas, auth as auth_utils, secrets
from datetime import datetime, timedelta, timezone
from email_utils import send_reset_email
from routers.settings import get_founding_50_enabled, get_founding_50_limit, get_founding_50_claimed
from collections import defaultdict
import os
import time

router = APIRouter(prefix="/auth", tags=["auth"])

# Current version of the terms accepted at sign-up (Membership Agreement +
# Privacy Policy + Member Manual). Bump when the terms — or the set of documents
# the checkbox covers — change, so we can tell which version a member accepted.
CURRENT_AGREEMENT_VERSION = "2026-07.2"

# Simple in-memory rate limiter: max 5 requests per IP per 60 seconds
_rate_store: dict[str, list[float]] = defaultdict(list)
_RATE_LIMIT = 5
_RATE_WINDOW = 60  # seconds

def _check_rate_limit(request: Request):
    ip = request.client.host if request.client else "unknown"
    now = time.time()
    timestamps = _rate_store[ip]
    # Drop entries outside the window
    _rate_store[ip] = [t for t in timestamps if now - t < _RATE_WINDOW]
    if len(_rate_store[ip]) >= _RATE_LIMIT:
        raise HTTPException(status_code=429, detail="Too many attempts. Please wait before trying again.")
    _rate_store[ip].append(now)


@router.post("/register", response_model=schemas.TokenResponse, status_code=201)
def register(payload: schemas.RegisterRequest, db: Session = Depends(get_db)):
    if db.query(models.User).filter(models.User.email == payload.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    # Privileged roles (admin, clinic) are provisioned server-side only
    # (seed.py / direct DB) — the public endpoint must never mint them.
    if payload.role != models.UserRole.member:
        raise HTTPException(
            status_code=403,
            detail="Registration is only available for members.",
        )

    # Members must accept the membership agreement + privacy terms to register.
    if payload.role == models.UserRole.member and not payload.agreement_accepted:
        raise HTTPException(
            status_code=400,
            detail="You must accept the Membership Agreement and Privacy Policy to continue.",
        )

    user = models.User(
        email=payload.email,
        password_hash=auth_utils.hash_password(payload.password),
        role=models.UserRole(payload.role),
    )
    db.add(user)
    db.flush()

    is_founding = False
    if payload.role == models.UserRole.member:
        reservation = (
            db.query(models.FoundingReservation)
            .filter(
                models.FoundingReservation.email == payload.email,
                models.FoundingReservation.status != "rejected",
            )
            .first()
        )
        if reservation and get_founding_50_enabled(db):
            limit = get_founding_50_limit(db)
            claimed = get_founding_50_claimed(db)
            if claimed < limit:
                is_founding = True
                if claimed + 1 >= limit:
                    # Last spot just taken — auto-close enrollment
                    row = db.query(models.AppSetting).filter(
                        models.AppSetting.key == "founding_50_enabled"
                    ).first()
                    if row:
                        row.value = "false"

    accepted_at = (
        datetime.now(timezone.utc)
        if payload.role == models.UserRole.member and payload.agreement_accepted
        else None
    )
    member = models.Member(
        user_id=user.id,
        first_name=payload.first_name,
        last_name=payload.last_name,
        phone=payload.phone,
        address=payload.address,
        is_founding=is_founding,
        agreement_accepted_at=accepted_at,
        agreement_version=(
            (payload.agreement_version or CURRENT_AGREEMENT_VERSION)
            if accepted_at
            else None
        ),
    )
    db.add(member)
    db.flush()

    db.commit()
    db.refresh(user)
    db.refresh(member)

    token = auth_utils.create_access_token({"sub": user.id, "role": user.role})
    return schemas.TokenResponse(
        access_token=token,
        role=user.role,
        member_id=member.id if user.role == models.UserRole.member else None,
        user_id=user.id,
    )


@router.get("/check-email")
def check_email(email: str, request: Request, db: Session = Depends(get_db), _: None = Depends(_check_rate_limit)):
    exists = db.query(models.User).filter(models.User.email == email).first() is not None
    return {"available": not exists}


@router.post("/login", response_model=schemas.TokenResponse)
def login(payload: schemas.LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == payload.email).first()
    if not user or not auth_utils.verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is inactive")

    member_id = None
    if user.role == models.UserRole.member and user.member:
        member_id = user.member.id

    token = auth_utils.create_access_token({"sub": user.id, "role": user.role})
    return schemas.TokenResponse(
        access_token=token,
        role=user.role,
        member_id=member_id,
        user_id=user.id,
    )


@router.get("/me")
def me(current_user: models.User = Depends(auth_utils.get_current_user)):
    return {
        "user_id": current_user.id,
        "email": current_user.email,
        "role": current_user.role,
    }


@router.post("/forgot-password")
def forgot_password(payload: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == payload.email).first()

    # Always return 200 for security (don't reveal if email exists)
    response = {"message": "If that email is registered, a reset link has been sent"}

    if not user:
        return response

    # Delete any existing tokens for this user
    db.query(models.PasswordResetToken).filter(
        models.PasswordResetToken.user_id == user.id
    ).delete()

    # Generate secure token
    token = secrets.token_hex(32)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=1)

    reset_token = models.PasswordResetToken(
        user_id=user.id,
        token=token,
        expires_at=expires_at,
    )
    db.add(reset_token)
    db.commit()

    # Send email
    frontend_url = os.getenv("FRONTEND_URL", "http://localhost:3000")
    reset_link = f"{frontend_url}/reset-password?token={token}"
    email_from_name = os.getenv("EMAIL_FROM_NAME", "MetroPaws")

    try:
        send_reset_email(user.email, reset_link, email_from_name)
    except Exception as e:
        # Log error but still return success response (email failure shouldn't expose system info)
        print(f"Error sending reset email: {e}")

    return response


@router.post("/reset-password")
def reset_password(payload: schemas.ResetPasswordRequest, db: Session = Depends(get_db)):
    reset_token = db.query(models.PasswordResetToken).filter(
        models.PasswordResetToken.token == payload.token
    ).first()

    if not reset_token:
        raise HTTPException(status_code=400, detail="Invalid or expired reset link")

    if datetime.now(timezone.utc) > reset_token.expires_at:
        db.delete(reset_token)
        db.commit()
        raise HTTPException(status_code=400, detail="Invalid or expired reset link")

    user = reset_token.user
    user.password_hash = auth_utils.hash_password(payload.new_password)

    db.delete(reset_token)
    db.commit()
    db.refresh(user)

    return {"message": "Password updated successfully"}
