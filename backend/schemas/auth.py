"""Registration, login, tokens, and password reset."""
from enum import Enum
from typing import Optional

from pydantic import BaseModel, EmailStr, field_validator

from schemas.validators import validate_ph_phone


class UserRole(str, Enum):
    member = "member"
    admin = "admin"
    clinic = "clinic"


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    first_name: str
    last_name: str
    phone: str
    address: Optional[str] = None
    role: UserRole = UserRole.member
    plan_id: Optional[str] = None
    # Digital Agreement acceptance (members must accept the membership terms +
    # privacy policy to register). Version identifies which terms were shown.
    agreement_accepted: bool = False
    agreement_version: Optional[str] = None

    @field_validator("phone", mode="before")
    @classmethod
    def phone_must_be_ph(cls, v):
        return validate_ph_phone(v)

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: UserRole
    member_id: Optional[str] = None
    user_id: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def password_min_length(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v
