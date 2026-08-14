from typing import Optional
from sqlalchemy.orm import Session
import models

POINTS_BY_TIER: dict[str, dict[str, int]] = {
    "membership_activation":     {"standard": 100, "deluxe": 200, "premium": 300},
    "pet_profile_completed":     {"standard": 50,  "deluxe": 75,  "premium": 100},
    "service_deployed_vet":      {"standard": 20,  "deluxe": 30,  "premium": 40},
    "service_deployed_grooming": {"standard": 15,  "deluxe": 25,  "premium": 35},
    "membership_renewal":        {"standard": 150, "deluxe": 300, "premium": 500},
}


def _normalize_tier(plan_type: Optional[str]) -> str:
    if not plan_type:
        return "standard"
    t = plan_type.lower()
    if "premium" in t:
        return "premium"
    if "deluxe" in t:
        return "deluxe"
    return "standard"


def award_points(
    db: Session,
    member_id: str,
    activity_type: str,
    plan_type: Optional[str] = None,
    points_override: Optional[int] = None,
    reference_id: Optional[str] = None,
    notes: Optional[str] = None,
) -> int:
    """
    Insert a PawPointsTransaction row. Returns points awarded (0 = nothing done).
    Caller is responsible for db.commit().
    """
    if points_override is not None:
        points = points_override
    else:
        tier = _normalize_tier(plan_type)
        points = POINTS_BY_TIER.get(activity_type, {}).get(tier, 0)

    if points == 0:
        return 0

    tx = models.PawPointsTransaction(
        member_id=member_id,
        points=points,
        activity_type=activity_type,
        reference_id=reference_id,
        notes=notes,
    )
    db.add(tx)
    return points


def has_awarded_for_reference(
    db: Session,
    member_id: str,
    activity_type: str,
    reference_id: str,
) -> bool:
    """Guard against double-awarding the same event."""
    return (
        db.query(models.PawPointsTransaction)
        .filter(
            models.PawPointsTransaction.member_id == member_id,
            models.PawPointsTransaction.activity_type == activity_type,
            models.PawPointsTransaction.reference_id == reference_id,
        )
        .first()
    ) is not None
