"""In-app notifications (the bell icon)."""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class NotificationOut(BaseModel):
    id: str
    title: str
    body: Optional[str] = None
    type: str
    reference_id: Optional[str] = None
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}
