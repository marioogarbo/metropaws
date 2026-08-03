"""One-off broadcast: tell members and Founding 50 reservations the app is live.

Recipients come from the admin XLSX exports (``GET /exports/members`` and
``GET /exports/founding-reservations``), not from the database — a run needs mail
credentials only, so it can be done from a laptop without touching production
Postgres. Re-exporting the spreadsheets is how you refresh the list.

Sending is opt-in: every mode except ``--send`` is harmless, and ``--send`` still
asks for confirmation. Delivered addresses are appended to a ledger file, so a
re-run after a crash or a timeout skips whoever already got the email.

Usage (from the ``backend`` directory):

    # Who would be emailed, and with which variant — sends nothing
    python notify_app_launch.py

    # Write the audience variants to HTML files to open in a browser
    python notify_app_launch.py --preview previews

    # Send every variant to one address to check how it lands in a real inbox
    python notify_app_launch.py --test you@example.com

    # The real broadcast
    python notify_app_launch.py --send

    # Missed one address, or a send failed after the ledger was written
    python notify_app_launch.py --send --only someone@example.com --resend
"""

import argparse
import os
import re
import sys
import time
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

import openpyxl
from dotenv import load_dotenv

load_dotenv()

from email_utils import (  # noqa: E402 — env must be loaded before the mail config is read
    AUDIENCE_FOUNDING_MEMBER,
    AUDIENCE_FOUNDING_RESERVATION,
    AUDIENCE_MEMBER,
    build_app_launch_email,
    send_app_launch_email,
)

# Export filenames are date-stamped (``..._2026-08-03.xlsx``), so the newest one
# sorts last by name. Looked up in this directory and in the repo root.
_SCRIPT_DIR = Path(__file__).resolve().parent
_SEARCH_DIRS = (_SCRIPT_DIR, _SCRIPT_DIR.parent)
_MEMBERS_GLOB = "metropaws_members_*.xlsx"
_RESERVATIONS_GLOB = "metropaws_founding_reservations_*.xlsx"

# Column headings written by routers/exports.py.
_COLUMN_EMAIL = "Email"
_COLUMN_FIRST_NAME = "First Name"
_COLUMN_PHONE = "Phone"
_COLUMN_FOUNDING_MEMBER = "Founding Member"

# Gmail ignores dots in the local part and anything after a "+", so two
# different-looking addresses can be the very same inbox. Duplicates are judged
# on this canonical form; mail still goes to the address as the member wrote it.
_DOT_INSENSITIVE_DOMAINS = frozenset({"gmail.com", "googlemail.com"})

# Reserved domains (RFC 2606 / 6761) can never receive mail, and the exports do
# carry test rows. Sending to them only buys bounces, which hurt sender
# reputation for everyone else in the batch. Internal or staff accounts are a
# judgement call, so those stay the operator's business via --exclude.
_UNDELIVERABLE_DOMAINS = frozenset(
    {"example.com", "example.net", "example.org", "invalid", "localhost", "test"}
)

_AUDIENCES = (AUDIENCE_FOUNDING_MEMBER, AUDIENCE_MEMBER, AUDIENCE_FOUNDING_RESERVATION)

_DEFAULT_LEDGER = _SCRIPT_DIR / "notify_app_launch_sent.log"
_DEFAULT_SLEEP_SECONDS = 0.6
_SAMPLE_NAME = "Maria"


@dataclass(frozen=True)
class Recipient:
    email: str
    first_name: str
    audience: str
    phone_key: str = ""  # last 10 digits, for spotting one person on two addresses

    @property
    def mailbox_key(self) -> str:
        """The inbox this address actually resolves to. Dedupe on this, not email."""
        return _mailbox_key(self.email)


@dataclass(frozen=True)
class Roster:
    """Who to email, and what was dropped on the way there."""

    recipients: list[Recipient]
    skipped: list[str]  # rows with no usable email address
    duplicates: int  # same inbox in both exports, emailed once
    same_person: list[list[Recipient]]  # distinct addresses that look like one person


# ── Reading the exports ───────────────────────────────────────────────────────
def _latest_export(pattern: str) -> Path:
    """Newest export matching ``pattern``, by date-stamped filename."""
    matches = sorted(
        (path for directory in _SEARCH_DIRS for path in directory.glob(pattern)),
        key=lambda path: path.name,
    )
    if not matches:
        searched = " or ".join(str(directory) for directory in _SEARCH_DIRS)
        raise SystemExit(f"No file matching {pattern} in {searched}")
    return matches[-1]


def _sheet_rows(path: Path) -> list[dict[str, object]]:
    """First worksheet of ``path`` as a list of header-keyed dicts."""
    workbook = openpyxl.load_workbook(path, read_only=True, data_only=True)
    try:
        rows = workbook.worksheets[0].iter_rows(values_only=True)
        header = ["" if cell is None else str(cell).strip() for cell in next(rows, ())]
        return [dict(zip(header, row)) for row in rows]
    finally:
        workbook.close()


def _cell(row: dict[str, object], column: str) -> str:
    value = row.get(column)
    return "" if value is None else str(value).strip()


def _normalised_email(raw: str) -> str:
    """Lower-cased address, or ``""`` when it can't be mailed.

    Deliberately not a full RFC check — just enough shape to reject blank cells,
    stray notes and reserved test domains before they turn into bounces.
    """
    email = raw.strip().lower()
    local_part, _, domain = email.partition("@")
    if not local_part or "." not in domain or any(char.isspace() for char in email):
        return ""
    if domain in _UNDELIVERABLE_DOMAINS or domain.rsplit(".", 1)[-1] in _UNDELIVERABLE_DOMAINS:
        return ""
    return email


def _mailbox_key(email: str) -> str:
    """Canonical inbox for ``email`` — two addresses with the same key are one inbox.

    Folds the Gmail aliases (``a.na.cruz+pets@googlemail.com`` and
    ``anacruz@gmail.com`` are one mailbox) and is a plain lower-cased address
    everywhere else, since other providers do treat dots as significant.
    """
    local_part, _, domain = email.strip().lower().partition("@")
    local_part = local_part.split("+", 1)[0]
    if domain in _DOT_INSENSITIVE_DOMAINS:
        local_part = local_part.replace(".", "")
        domain = "gmail.com"
    return f"{local_part}@{domain}"


def _phone_key(raw: str) -> str:
    """Last 10 digits of a mobile number, or ``""`` when there aren't 10.

    Members retype their number at every signup as ``09xx``, ``+639xx`` or
    ``9xx``, so only the tail is comparable.
    """
    digits = re.sub(r"\D", "", raw)
    return digits[-10:] if len(digits) >= 10 else ""


def _greeting_name(raw: str) -> str:
    """First name for the greeting, case-repaired for spreadsheet typing.

    Members type their own names, so the exports hold "GLADYS" and "mary
    stephanie" alongside properly-cased entries. Only all-caps and all-lower
    tokens are re-cased; mixed case is left alone so "McSmith" survives.
    """
    first_token = raw.strip().split(" ")[0]
    if first_token.isupper() or first_token.islower():
        return first_token.capitalize()
    return first_token


def _load_export(path: Path, audience_of: Callable[[dict], str]) -> tuple[list[Recipient], list[str]]:
    """Recipients from one export, plus notes for rows that had no usable email."""
    recipients: list[Recipient] = []
    skipped: list[str] = []
    for row_number, row in enumerate(_sheet_rows(path), start=2):  # row 1 is the header
        email = _normalised_email(_cell(row, _COLUMN_EMAIL))
        if not email:
            raw = _cell(row, _COLUMN_EMAIL) or "(blank)"
            skipped.append(f"{path.name} row {row_number}: unusable email {raw!r}")
            continue
        recipients.append(
            Recipient(
                email=email,
                first_name=_greeting_name(_cell(row, _COLUMN_FIRST_NAME)),
                audience=audience_of(row),
                phone_key=_phone_key(_cell(row, _COLUMN_PHONE)),
            )
        )
    return recipients, skipped


def _member_audience(row: dict[str, object]) -> str:
    is_founding = _cell(row, _COLUMN_FOUNDING_MEMBER).lower() == "yes"
    return AUDIENCE_FOUNDING_MEMBER if is_founding else AUDIENCE_MEMBER


def _same_person_groups(recipients: list[Recipient]) -> list[list[Recipient]]:
    """Groups of recipients that look like one person on two different addresses.

    Matched on phone number. This is a hint, not a fact — a household can share
    one mobile — so these are reported for a human decision rather than collapsed
    automatically: silently dropping a real Founding 50 reservation is worse than
    one person getting two emails.
    """
    by_phone: dict[str, list[Recipient]] = defaultdict(list)
    for recipient in recipients:
        if recipient.phone_key:
            by_phone[recipient.phone_key].append(recipient)
    return [group for group in by_phone.values() if len(group) > 1]


def _build_roster(members_path: Path, reservations_path: Path) -> Roster:
    """One recipient per inbox across both exports.

    Deduped on ``mailbox_key``, so a member who also reserved early — or who used
    a Gmail dot/+alias variant on one of the two forms — is emailed exactly once.
    Members are loaded first and win the collision, which is what makes the copy
    correct: their variant comes from the members export's Founding Member column
    alone. That column is the approved-reservation flag, so someone whose
    reservation is still pending gets the plain member copy rather than being
    addressed as a Founding Member. Addresses that appear only in the
    reservations export get the "finish signing up in the app" variant.
    """
    members, skipped_members = _load_export(members_path, _member_audience)
    reservations, skipped_reservations = _load_export(
        reservations_path, lambda _row: AUDIENCE_FOUNDING_RESERVATION
    )

    unique: dict[str, Recipient] = {}
    for recipient in [*members, *reservations]:
        unique.setdefault(recipient.mailbox_key, recipient)  # first wins, so members win

    recipients = list(unique.values())
    return Roster(
        recipients=recipients,
        skipped=skipped_members + skipped_reservations,
        duplicates=len(members) + len(reservations) - len(recipients),
        same_person=_same_person_groups(recipients),
    )


# ── Ledger ────────────────────────────────────────────────────────────────────
def _already_sent(ledger: Path) -> set[str]:
    """Canonical inboxes this broadcast has already reached."""
    if not ledger.exists():
        return set()
    return {
        _mailbox_key(line.split("\t")[0])
        for line in ledger.read_text(encoding="utf-8").splitlines()
        if line.strip()
    }


def _record_sent(ledger: Path, recipient: Recipient) -> None:
    sent_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    with ledger.open("a", encoding="utf-8") as handle:
        handle.write(f"{recipient.email}\t{recipient.audience}\t{sent_at}\n")


# ── Modes ─────────────────────────────────────────────────────────────────────
def _mail_transport() -> str:
    """Human-readable transport summary. Exits if no sender is configured."""
    sender = os.getenv("EMAIL_FROM") or os.getenv("SMTP_USER")
    if not sender:
        raise SystemExit("No sender configured - set EMAIL_FROM (or SMTP_USER) in .env")
    transport = "ZeptoMail API" if os.getenv("ZEPTOMAIL_TOKEN") else "SMTP"
    return f"{transport}, from {sender}"


def _write_previews(directory: Path) -> int:
    directory.mkdir(parents=True, exist_ok=True)
    for audience in _AUDIENCES:
        subject, html_body = build_app_launch_email(_SAMPLE_NAME, audience)
        path = directory / f"{audience}.html"
        path.write_text(html_body, encoding="utf-8")
        print(f"  {path}\n    subject: {subject}")
    print("\nNothing sent. Open the files above in a browser to check the layout.")
    return 0


def _send_previews_to(address: str, sleep_seconds: float) -> int:
    """Send one copy of each variant to a single address. Never uses the ledger."""
    print(f"Transport: {_mail_transport()}")
    print(f"Sending {len(_AUDIENCES)} test emails to {address}\n")

    failures = 0
    for position, audience in enumerate(_AUDIENCES, start=1):
        try:
            send_app_launch_email(address, _SAMPLE_NAME, audience)
        except Exception as error:
            failures += 1
            print(f"  {audience}: FAILED - {error}")
            continue
        print(f"  {audience}: sent")
        if sleep_seconds and position < len(_AUDIENCES):
            time.sleep(sleep_seconds)

    print("\nDone." if not failures else f"\n{failures} test email(s) failed.")
    return 1 if failures else 0


def _print_same_person_warning(groups: list[list[Recipient]], recipients: list[Recipient]) -> None:
    """Flag one-person-two-addresses groups still standing after all filters."""
    on_the_list = {recipient.mailbox_key for recipient in recipients}
    live_groups = [
        [recipient for recipient in group if recipient.mailbox_key in on_the_list]
        for group in groups
    ]
    live_groups = [group for group in live_groups if len(group) > 1]
    if not live_groups:
        return

    print(
        f"\n{len(live_groups)} person(s) appear to hold two addresses (same phone number)."
        "\nThese are different inboxes, so both would be emailed. Your call:"
    )
    for group in live_groups:
        print(f"  phone ...{group[0].phone_key}")
        for recipient in group:
            print(f"      {recipient.email:<34} {recipient.audience:<22} {recipient.first_name}")
    drop = " ".join(f"--exclude {group[-1].email}" for group in live_groups)
    print(f"\n  To email only the first of each pair, add:\n    {drop}")


def _print_plan(
    members_path: Path,
    reservations_path: Path,
    roster: Roster,
    recipients: list[Recipient],
    not_emailed: list[str],
    previously_sent: int,
) -> None:
    print(f"Members export:      {members_path}")
    print(f"Reservations export: {reservations_path}")
    print(f"Transport:           {_mail_transport()}\n")

    for audience in _AUDIENCES:
        count = sum(1 for recipient in recipients if recipient.audience == audience)
        print(f"  {audience:<22} {count}")
    print(f"  {'total':<22} {len(recipients)}")

    if roster.duplicates:
        print(f"\n{roster.duplicates} address(es) in both exports, emailed once.")
    if previously_sent:
        print(f"{previously_sent} address(es) already in the ledger, skipped (--resend overrides).")
    if not_emailed:
        print(f"\n{len(not_emailed)} row(s) not emailed:")
        for note in not_emailed:
            print(f"  {note}")

    if recipients:
        print("\nRecipients:")
        for recipient in recipients:
            print(f"  {recipient.email:<38} {recipient.audience:<22} Hi {recipient.first_name or 'there'},")

    _print_same_person_warning(roster.same_person, recipients)


def _confirmed(count: int) -> bool:
    answer = input(f'\nSend to {count} recipient(s)? Type "SEND" to confirm: ')
    return answer.strip() == "SEND"


def _broadcast(recipients: list[Recipient], sleep_seconds: float, ledger: Path) -> int:
    failures: list[str] = []
    mailed: set[str] = set()  # last line of defence against emailing an inbox twice
    total = len(recipients)

    print()
    for position, recipient in enumerate(recipients, start=1):
        label = f"[{position}/{total}] {recipient.email}"
        if recipient.mailbox_key in mailed:
            print(f"{label} skipped - same inbox already emailed in this run")
            continue
        try:
            send_app_launch_email(recipient.email, recipient.first_name, recipient.audience)
        except Exception as error:  # one bad address must not stop the broadcast
            failures.append(f"{recipient.email}: {error}")
            print(f"{label} FAILED - {error}")
            continue
        mailed.add(recipient.mailbox_key)
        _record_sent(ledger, recipient)
        print(f"{label} sent")
        if sleep_seconds and position < total:
            time.sleep(sleep_seconds)

    print(f"\nSent {len(mailed)} of {total}. Ledger: {ledger}")
    if failures:
        print(f"{len(failures)} failed:")
        for failure in failures:
            print(f"  {failure}")
    return 1 if failures else 0


# ── CLI ───────────────────────────────────────────────────────────────────────
def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Email members and Founding 50 reservations that the Android app is live.",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--send",
        action="store_true",
        help="actually deliver to the roster (default is a dry run that sends nothing)",
    )
    mode.add_argument(
        "--test",
        metavar="EMAIL",
        help="send one of each audience variant to this address only, then exit",
    )
    mode.add_argument(
        "--preview",
        metavar="DIR",
        help="write the audience variants to HTML files in DIR, then exit",
    )

    parser.add_argument("--members", metavar="XLSX", help="members export (default: newest found)")
    parser.add_argument(
        "--reservations", metavar="XLSX", help="founding reservations export (default: newest found)"
    )
    parser.add_argument(
        "--only",
        metavar="EMAIL",
        action="append",
        default=[],
        help="restrict the roster to this address (repeatable)",
    )
    parser.add_argument(
        "--exclude",
        metavar="EMAIL",
        action="append",
        default=[],
        help="drop this address, e.g. an internal or staff account (repeatable)",
    )
    parser.add_argument("--limit", type=int, metavar="N", help="stop after the first N recipients")
    parser.add_argument(
        "--sleep",
        type=float,
        default=_DEFAULT_SLEEP_SECONDS,
        metavar="SECONDS",
        help=f"pause between sends (default {_DEFAULT_SLEEP_SECONDS})",
    )
    parser.add_argument(
        "--ledger",
        default=str(_DEFAULT_LEDGER),
        metavar="PATH",
        help=f"record of delivered addresses (default {_DEFAULT_LEDGER.name})",
    )
    parser.add_argument(
        "--resend", action="store_true", help="ignore the ledger and email everyone again"
    )
    parser.add_argument(
        "--yes", action="store_true", help="skip the confirmation prompt (for --send)"
    )
    return parser.parse_args()


def _use_utf8_console() -> None:
    """Keep console output from killing a run in progress.

    Names, subjects and em dashes are not encodable on a legacy Windows console
    (cp437/cp1252), and an unlucky ``print`` raising UnicodeEncodeError halfway
    through a broadcast would abort it after mail had already gone out.
    """
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure:
            reconfigure(encoding="utf-8", errors="replace")


def main() -> int:
    _use_utf8_console()
    args = _parse_args()

    if args.preview:
        return _write_previews(Path(args.preview))
    if args.test:
        return _send_previews_to(args.test, args.sleep)

    members_path = Path(args.members) if args.members else _latest_export(_MEMBERS_GLOB)
    reservations_path = (
        Path(args.reservations) if args.reservations else _latest_export(_RESERVATIONS_GLOB)
    )
    roster = _build_roster(members_path, reservations_path)

    candidates = roster.recipients
    not_emailed = list(roster.skipped)
    if args.only:
        wanted = {_mailbox_key(address) for address in args.only}
        candidates = [recipient for recipient in candidates if recipient.mailbox_key in wanted]
    if args.exclude:
        unwanted = {_mailbox_key(address) for address in args.exclude}
        not_emailed += [
            f"excluded by --exclude: {recipient.email}"
            for recipient in candidates
            if recipient.mailbox_key in unwanted
        ]
        candidates = [
            recipient for recipient in candidates if recipient.mailbox_key not in unwanted
        ]

    ledger = Path(args.ledger)
    already_sent = set() if args.resend else _already_sent(ledger)
    recipients = [
        recipient for recipient in candidates if recipient.mailbox_key not in already_sent
    ]
    previously_sent = len(candidates) - len(recipients)
    if args.limit:
        recipients = recipients[: args.limit]

    _print_plan(
        members_path,
        reservations_path,
        roster,
        recipients,
        not_emailed,
        previously_sent,
    )

    if not args.send:
        print("\nDry run - nothing sent. Add --send to deliver.")
        return 0
    if not recipients:
        print("\nNothing to send.")
        return 0
    if not args.yes and not _confirmed(len(recipients)):
        print("Aborted - nothing sent.")
        return 1
    return _broadcast(recipients, args.sleep, ledger)


if __name__ == "__main__":
    sys.exit(main())
