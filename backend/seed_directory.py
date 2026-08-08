"""Seed the public pet-care directory with the launch listings.

Idempotent, matched on name: a re-run inserts only what is missing and never
overwrites a row, so running it again after the client has edited hours or a
phone number in the admin panel does not clobber their work.

    python seed_directory.py

Run against dev, then prod, before the deploy that exposes /find-pet-care.

Source: 19 businesses supplied by the client on 2026-08-08, compiled from
publicly posted contact details. Two normalisations were applied to their
category strings: "Pet Grooming" -> Grooming and "Pet Boarding" -> Boarding, so
the same service reads the same on every card. Placeholder contacts ("Please
verify directly with the clinic") are stored verbatim rather than blanked — the
website renders anything without a dialable number as muted text instead of a
tel: link, so the honest state of the data survives to the page.
"""

from database import SessionLocal, engine
import models

models.Base.metadata.create_all(bind=engine)

LISTINGS = [
    {
        "name": "FMH Animal Clinic",
        "services": ["veterinary"],
        "address": "11 Ruby St., corner Dona Pilar Aguirre Rd., Pilar, Las Piñas",
        "phone": "(02) 8806 5772",
        "hours": "Mon-Sat 8:00 AM-7:00 PM; Sun 8:00 AM-3:00 PM",
    },
    {
        "name": "New Alabang Veterinary Center",
        "services": ["veterinary", "diagnostics", "surgery"],
        "address": "Unit 102 UGF Southbend Bldg., Versailles Subd., Daang Hari, Almanza Dos, Las Piñas 1750",
        "phone": "0919 007 6282 / (02) 8804 3248",
        "email": "info@newalabangvet.com",
        "website": "https://newalabangvet.com/",
        "hours": "Daily 9:00 AM-5:00 PM; by appointment",
    },
    {
        "name": "Vets in Practice Animal Hospital - Alabang",
        "services": ["animal_hospital", "veterinary"],
        "address": "G/F A103B, One Town Square Place, The Village Square, La Fuerza Compound, Alabang-Zapote Rd., Almanza Uno, Las Piñas",
        "phone": "(02) 8842 8379 / (02) 8846 7730 / 0917 560 5859",
        "email": "alabang@vetsinpractice.ph",
        "website": "https://vetsinpractice.ph/",
        "hours": "Daily 9:00 AM-6:00 PM",
    },
    {
        "name": "Royal Petcare Veterinary Clinic by SanCorBab",
        "services": ["veterinary", "emergency"],
        "address": "1740 Alabang-Zapote Rd., Talon, Las Piñas 1740",
        "phone": "+63 993 572 1371",
        "hours": "Open 24 hours",
    },
    {
        "name": "Furryhome Animal Clinic",
        "services": ["veterinary"],
        "address": "139 Naga Rd., Las Piñas 1740",
        "phone": "+63 945 170 3234",
        "hours": "Tue-Sun 9:30 AM-6:30 PM",
    },
    {
        "name": "Petunia Veterinary Clinic",
        "services": ["veterinary", "grooming", "emergency"],
        "address": "Unit 1C Jin Sam Bldg., Abel Nosce St., BF Resort Village, Talon Dos, Las Piñas",
        "phone": "0916 267 3857 / (02) 8777 1068",
        "hours": "Vet 9:00 AM-5:30 PM; grooming 8:00 AM-5:30 PM; after-hours emergency subject to availability",
    },
    {
        "name": "Golden Bunch Veterinary Clinic & Pet Grooming Center",
        "services": ["veterinary", "grooming", "boarding", "pet_supplies"],
        "address": "1330 Fruto Santos Ave., Brgy. Zapote, Las Piñas",
        "phone": "(02) 8647 6491",
        "hours": "Veterinary doctors generally 9:00 AM-6:00 PM; call ahead",
    },
    {
        "name": "EV Dog and Cat Clinic LPC",
        "services": ["veterinary"],
        "address": "16 Marcos Alvarez Ave., Las Piñas 1747",
        "phone": "(02) 7341 2473",
        "hours": "Daily 9:30 AM-5:30 PM",
    },
    {
        "name": "South Paws Animal Clinic - Las Piñas",
        "services": ["veterinary", "grooming", "boarding", "pet_supplies"],
        "address": "107 Real St., Alabang-Zapote Rd., Pamplona Uno, Las Piñas 1740",
        "phone": "+63 927 818 7025",
        "hours": "Most days 10:00 AM-6:00 PM; verify before visit",
    },
    {
        "name": "South Metro Veterinary Clinic",
        "services": ["veterinary"],
        "address": "BF Resort Village, Las Piñas City",
        "phone": "Please verify directly with the clinic",
        "hours": "Please verify before visiting",
    },
    {
        "name": "DOGLAB Pet Grooming",
        "services": ["grooming"],
        "address": "GF Omni Gold Bldg., Alabang-Zapote Rd., Las Piñas 1740",
        "phone": "+63 926 683 3217",
        "hours": "Daily 9:00 AM-6:00 PM",
    },
    {
        "name": "Glam Grooms Pet Spa and Hotel",
        "services": ["grooming", "pet_hotel"],
        "address": "Pr1MO Building, Gloria Diaz, Las Piñas 1747",
        "phone": "+63 960 867 2330",
        "hours": "Mon-Sat 9:00 AM-6:00 PM; Sun 6:00 AM-6:00 PM",
    },
    {
        "name": "Paw Station Grooming and Hotel",
        "services": ["grooming", "pet_hotel"],
        "address": "BF Resort Village, Las Piñas City",
        "phone": "Please verify directly with the establishment",
        "hours": "Please verify before visiting",
    },
    {
        "name": "Mighty Waggers Pet Supplies & Pet Grooming",
        "services": ["pet_supplies", "grooming"],
        "address": "Unit 3 Fuji-O Residences, corner Charlemagne-Abel Nosce St., BF Resort Dr., Las Piñas 1740",
        "phone": "+63 999 814 4464",
        "hours": "Daily 8:00 AM-7:30 PM",
    },
    {
        "name": "Zoey's Pet Shop",
        "services": ["pet_store"],
        "address": "102 Marcos Alvarez Ave., Las Piñas 1747",
        "phone": "+63 925 550 1004",
        "hours": "Mon-Sat 8:00 AM-7:00 PM; Sun 8:00 AM-1:00 PM",
    },
    {
        "name": "Johan's Pet Store BFRV Las Piñas",
        "services": ["pet_store"],
        "address": "123A Gloria Diaz, Talon Dos, Las Piñas 1747",
        "phone": "+63 917 190 5252",
        "hours": "Daily 9:00 AM-9:00 PM",
    },
    {
        "name": "Kaboochi Pet Shop",
        "services": ["pet_store"],
        "address": "Lot 8 Blk 10 Cordillera St., Bermuda Country Subdivision, Las Piñas 1740",
        "phone": "Please verify directly",
        "hours": "Daily 8:00 AM-8:00 PM",
    },
    {
        "name": "Cat Chingu",
        "services": ["boarding"],
        "address": "JB Tan, BF Resort Dr., Talon Dos, Las Piñas 1747",
        "phone": "+63 956 496 3906",
        "hours": "Daily 11:00 AM-7:00 PM",
    },
    {
        "name": "Sit. Stay. Play. Ph",
        "services": ["boarding"],
        "address": "39 Epifania Lagman, BF Resort Village, Las Piñas 1747",
        "phone": "+63 915 980 1808",
        "hours": "Daily 8:00 AM-8:00 PM",
    },
]


def _console_safe(text: str) -> str:
    """Windows consoles default to cp1252 and choke on the tilde-n in Piñas."""
    return text.encode("ascii", "replace").decode("ascii")


def main() -> None:
    db = SessionLocal()
    try:
        added = 0
        for listing in LISTINGS:
            exists = (
                db.query(models.DirectoryProvider)
                .filter(models.DirectoryProvider.name == listing["name"])
                .first()
            )
            if exists:
                continue
            db.add(models.DirectoryProvider(**listing))
            added += 1
            print(f"  + {_console_safe(listing['name'])}")
        db.commit()
        total = db.query(models.DirectoryProvider).count()
        print(f"Directory seed complete. Added {added}, skipped {len(LISTINGS) - added}, {total} listings on file.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
