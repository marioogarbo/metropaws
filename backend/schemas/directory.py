"""Pet care directory — public community listings."""
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator

import directory_taxonomy


def _clean_services(v):
    """Drop blanks, then reject anything outside the shared vocabulary.

    Runs `mode="before"` so a form that posts an empty checkbox value doesn't
    trip the validator with a "" slug the operator never chose.
    """
    if v is None:
        return v
    cleaned = [s.strip() for s in v if isinstance(s, str) and s.strip()]
    return directory_taxonomy.validate_services(cleaned)


def _strip_name(v):
    return v.strip() if isinstance(v, str) else v


class DirectoryProviderCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    services: List[str] = []
    address: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    website: Optional[str] = None
    hours: Optional[str] = None
    map_url: Optional[str] = None
    is_partner: bool = False
    is_published: bool = True

    @field_validator("services", mode="before")
    @classmethod
    def services_must_be_known(cls, v):
        return _clean_services(v)

    @field_validator("name", mode="before")
    @classmethod
    def name_is_trimmed(cls, v):
        return _strip_name(v)


class DirectoryProviderUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    services: Optional[List[str]] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    website: Optional[str] = None
    hours: Optional[str] = None
    map_url: Optional[str] = None
    is_partner: Optional[bool] = None
    is_published: Optional[bool] = None

    @field_validator("services", mode="before")
    @classmethod
    def services_must_be_known(cls, v):
        return _clean_services(v)

    @field_validator("name", mode="before")
    @classmethod
    def name_is_trimmed(cls, v):
        return _strip_name(v)


class DirectoryProviderOut(BaseModel):
    id: str
    name: str
    services: List[str]
    address: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    website: Optional[str] = None
    hours: Optional[str] = None
    map_url: Optional[str] = None
    is_partner: bool
    is_published: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}
