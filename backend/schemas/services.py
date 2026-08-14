"""Service categories and the session records built on them.

ServiceTypeOut is the most widely reused shape in the package — most other
modules depend on this one, and it depends on none of them.
"""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class ServiceTypeOut(BaseModel):
    id: str
    name: str
    description: Optional[str]
    icon: str

    model_config = {"from_attributes": True}


class MemberServiceOut(BaseModel):
    id: str
    service_type: ServiceTypeOut
    total_sessions: int
    used_sessions: int
    remaining_sessions: int
    expires_at: Optional[datetime]

    model_config = {"from_attributes": True}


class PetServiceOut(BaseModel):
    id: str
    service_type: ServiceTypeOut
    total_sessions: int
    used_sessions: int
    remaining_sessions: int
    expires_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class DeployServiceRequest(BaseModel):
    member_id: str
    service_type_id: str
    pet_id: Optional[str] = None
    notes: Optional[str] = None


class ServiceLogOut(BaseModel):
    id: str
    service_type: ServiceTypeOut
    notes: Optional[str]
    logged_at: datetime

    model_config = {"from_attributes": True}


class AssignServiceRequest(BaseModel):
    member_id: str
    service_type_id: str
    total_sessions: int
    expires_at: Optional[datetime] = None


class ServiceLogBriefOut(BaseModel):
    id: str
    service_type: ServiceTypeOut
    notes: Optional[str]
    logged_at: datetime

    model_config = {"from_attributes": True}
