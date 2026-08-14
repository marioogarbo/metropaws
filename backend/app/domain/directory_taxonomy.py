"""Canonical service vocabulary for the public pet-care directory.

A directory listing stores a LIST of these slugs rather than the client's
free-text category line ("Veterinary / Grooming / Boarding / Supplies"), because
the website filters by service and a place that is both a clinic and a groomer
has to appear under both filters.

MIRRORED IN `website/lib/directory-taxonomy.ts` — the website renders the labels
and derives its filter chips from its own copy. Adding a service means editing
BOTH files. That is deliberate: a slug the website doesn't know would render
blank, and one no filter group claims would silently vanish from every chip.
"""

# slug -> label shown to visitors, joined with " / " to form the category line.
SERVICE_LABELS: dict[str, str] = {
    "veterinary": "Veterinary",
    "animal_hospital": "Animal Hospital",
    "emergency": "Emergency",
    "diagnostics": "Diagnostics",
    "surgery": "Surgery",
    "grooming": "Grooming",
    "boarding": "Boarding",
    "pet_hotel": "Pet Hotel",
    "pet_store": "Pet Store",
    "pet_supplies": "Pet Supplies",
}

SERVICE_SLUGS = frozenset(SERVICE_LABELS)


def validate_services(services: list[str]) -> list[str]:
    """Return the list unchanged, or raise ValueError naming the bad slugs.

    Order is preserved — it is the order the labels appear in on the card, so
    "Veterinary / Grooming" and "Grooming / Veterinary" are both legal and mean
    different things about what the place leads with.
    """
    unknown = [s for s in services if s not in SERVICE_SLUGS]
    if unknown:
        raise ValueError(
            f"Unknown service(s): {', '.join(unknown)}. "
            f"Allowed: {', '.join(sorted(SERVICE_SLUGS))}"
        )
    return services
