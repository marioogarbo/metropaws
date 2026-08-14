"""Field validators shared across more than one schema module."""
import re
from typing import Optional


def validate_ph_phone(v: Optional[str]) -> Optional[str]:
    """Normalise and validate a PH mobile number.
    Accepts: 9XXXXXXXXX, 09XXXXXXXXX, +639XXXXXXXXX, 639XXXXXXXXX.
    Always stores as 10-digit local number starting with 9.
    """
    if v is None or v.strip() == "":
        return v
    digits = re.sub(r"\D", "", v)
    # Strip country code: 63 prefix (e.g. +63 or 63...)
    if digits.startswith("63") and len(digits) == 12:
        digits = digits[2:]
    # Strip leading 0 (e.g. 09...)
    elif digits.startswith("0"):
        digits = digits[1:]
    if len(digits) != 10:
        raise ValueError("Phone number must be 10 digits (e.g. 9171234567)")
    if not digits.startswith("9"):
        raise ValueError("Philippine mobile numbers must start with 9")
    return digits
