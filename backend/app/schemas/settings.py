"""App settings and feature flags, including the ones the mobile app reads at startup."""

from pydantic import BaseModel, Field


class AppSettingOut(BaseModel):
    key: str
    value: str

    model_config = {"from_attributes": True}


class PaymentsEnabledOut(BaseModel):
    payments_enabled: bool


class PaymentsEnabledUpdate(BaseModel):
    payments_enabled: bool

    model_config = {"from_attributes": True}


class Founding50Out(BaseModel):
    enabled: bool
    limit: int
    claimed: int


class Founding50Update(BaseModel):
    enabled: bool
    limit: int = 50


class FoundingStatusUpdate(BaseModel):
    is_founding: bool


class MobileConfigOut(BaseModel):
    booking_enabled: bool
    direct_provider_payment_enabled: bool = False


class BookingEnabledUpdate(BaseModel):
    booking_enabled: bool


class DirectProviderPaymentUpdate(BaseModel):
    direct_provider_payment_enabled: bool


class PackDiscountOut(BaseModel):
    enabled: bool
    percent: int


class PackDiscountUpdate(BaseModel):
    enabled: bool
    percent: int = Field(ge=0, le=100)
