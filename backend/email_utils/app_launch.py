"""The one-off Android launch announcement, in three audience variants.

Sent by the notify_app_launch.py CLI, not by the API.
"""
from dataclasses import dataclass
from html import escape

from email_utils.layout import _branded_shell
from email_utils.transport import _send_email


# Mirrors website/lib/app-download.ts, which is the source of truth for install
# links. There is deliberately no App Store URL — iOS hasn't shipped yet.
PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.metropaws.mobile"


# Audience keys accepted by build_app_launch_email / send_app_launch_email.
AUDIENCE_FOUNDING_MEMBER = "founding_member"


AUDIENCE_FOUNDING_RESERVATION = "founding_reservation"


AUDIENCE_MEMBER = "member"


@dataclass(frozen=True)
class _LaunchCopy:
    """Per-audience wording for the launch announcement.

    Only these four strings change between audiences — the Play Store call to
    action, the feature list and the iOS section are identical for everyone.
    """

    subject: str
    intro: str
    aside: str = ""  # highlighted strip under the intro; blank = not rendered
    footer_note: str = ""


_ACCOUNT_FOOTER_NOTE = (
    "You're receiving this because you have a MetroPaws membership account."
)


_LAUNCH_COPY: dict[str, _LaunchCopy] = {
    AUDIENCE_FOUNDING_MEMBER: _LaunchCopy(
        subject="Founding Member: the MetroPaws app is live on Google Play",
        intro=(
            "You joined MetroPaws before there was an app to show for it — thank you "
            "for that trust. It's here now, and everything on your membership is in it."
        ),
        aside=(
            "Your <strong>Founding Member</strong> status is already on your account. "
            "Sign in with this same email address and you'll find it waiting."
        ),
        footer_note=_ACCOUNT_FOOTER_NOTE,
    ),
    AUDIENCE_MEMBER: _LaunchCopy(
        subject="The MetroPaws app is now live on Google Play",
        intro=(
            "Your membership now has a proper home on your phone. The MetroPaws app "
            "is live on Google Play, and your account is ready to sign in to."
        ),
        footer_note=_ACCOUNT_FOOTER_NOTE,
    ),
    AUDIENCE_FOUNDING_RESERVATION: _LaunchCopy(
        subject="The MetroPaws app is live — your Founding 50 slot is waiting",
        intro=(
            "You reserved one of our Founding 50 slots early on, and we've kept it — "
            "thank you. The MetroPaws app is now live on Google Play, and it's where "
            "you finish setting up your membership."
        ),
        aside=(
            "Your <strong>Founding 50 reservation</strong> is on file with our team. "
            "Create your account in the app using this same email address and we'll "
            "match it to your slot."
        ),
        footer_note=(
            "You're receiving this because you reserved a Founding 50 slot at metropaws.ph."
        ),
    ),
}


# Only features that actually ship in the Android build — nothing aspirational.
_LAUNCH_FEATURES = (
    (
        "Your digital membership ID",
        "A scannable QR code that pulls up you and your pets at the counter.",
    ),
    (
        "Every pet in one place",
        "Photos, breed, weight and vaccination cards, kept with the pet they belong to.",
    ),
    (
        "Benefits you can actually see",
        "What your plan covers, what's left in your Benefit Wallet, and the Paw Points you've earned.",
    ),
    (
        "Reimbursement claims from your phone",
        "Paid out of pocket? Send the receipt and follow the claim through to release.",
    ),
)


def build_app_launch_email(first_name: str, audience: str) -> tuple[str, str]:
    """Return ``(subject, html_body)`` for the Android launch announcement.

    ``audience`` is one of the ``AUDIENCE_*`` constants. Raises ``ValueError`` on
    anything else rather than guessing — the wrong variant would tell someone
    they're a Founding Member when they aren't.
    """
    if audience not in _LAUNCH_COPY:
        raise ValueError(
            f"Unknown audience {audience!r}; expected one of {sorted(_LAUNCH_COPY)}"
        )
    copy = _LAUNCH_COPY[audience]

    # Names come from an admin spreadsheet export, so escape before interpolating.
    greeting_name = escape((first_name or "").strip()) or "there"

    features_html = "".join(
        f"""
                  <tr>
                    <td width="26" valign="top"
                        style="padding:0 0 16px;font-size:15px;line-height:1.5;color:#b89a3e;">&#10003;</td>
                    <td valign="top"
                        style="padding:0 0 16px;font-size:14px;line-height:1.55;color:#4a4f6a;">
                      <strong style="color:#1a1e32;">{title}</strong><br>{detail}
                    </td>
                  </tr>"""
        for title, detail in _LAUNCH_FEATURES
    )

    aside_html = ""
    if copy.aside:
        aside_html = f"""
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                       style="margin:0 0 26px;background:#fbf6e9;border-radius:8px;">
                  <tr>
                    <td width="4" style="background:#b89a3e;font-size:0;line-height:0;">&nbsp;</td>
                    <td style="padding:14px 18px;font-size:14px;line-height:1.6;color:#4a4f6a;">
                      {copy.aside}
                    </td>
                  </tr>
                </table>"""

    card_rows = f"""
              <!-- Headline + intro -->
              <tr><td style="padding:34px 32px 0;font-family:Arial,Helvetica,sans-serif;">
                <p style="margin:0 0 10px;font-size:11px;font-weight:bold;letter-spacing:1.4px;
                          text-transform:uppercase;color:#b89a3e;">
                  Now on Google Play
                </p>
                <h1 style="margin:0 0 18px;font-size:26px;line-height:1.25;font-weight:bold;color:#263258;">
                  The MetroPaws app is here
                </h1>
                <p style="margin:0 0 16px;font-size:15px;line-height:1.65;color:#1a1e32;">
                  Hi {greeting_name},
                </p>
                <p style="margin:0 0 26px;font-size:15px;line-height:1.65;color:#4a4f6a;">
                  {copy.intro}
                </p>
                {aside_html}
                <!-- Primary call to action -->
                <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 8px;">
                  <tr><td style="border-radius:12px;background:#263258;">
                    <a href="{PLAY_STORE_URL}"
                       style="display:inline-block;padding:14px 34px;font-family:Arial,sans-serif;
                              font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none;
                              border-radius:12px;">
                      Get it on Google Play
                    </a>
                  </td></tr>
                </table>
                <p style="margin:0 0 30px;font-size:12px;line-height:1.5;color:#a0a4bd;">
                  Button not working? Search <strong style="color:#8b8fa8;">MetroPaws</strong>
                  on the Google Play Store.
                </p>
              </td></tr>
              <!-- What's inside -->
              <tr><td style="padding:0 32px;font-family:Arial,Helvetica,sans-serif;">
                <p style="margin:0 0 16px;font-size:12px;font-weight:bold;letter-spacing:1px;
                          text-transform:uppercase;color:#263258;">
                  What's waiting inside
                </p>
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0">{features_html}
                </table>
              </td></tr>
              <!-- iOS status -->
              <tr><td style="padding:10px 32px 0;font-family:Arial,Helvetica,sans-serif;">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                       style="background:#f7f8fb;border:1px solid #eef0f8;border-radius:12px;">
                  <tr><td style="padding:20px 22px;">
                    <p style="margin:0 0 8px;font-size:11px;font-weight:bold;letter-spacing:1.2px;
                              text-transform:uppercase;color:#b89a3e;">
                      iPhone &amp; iPad — in progress
                    </p>
                    <p style="margin:0 0 12px;font-size:15px;font-weight:bold;color:#263258;">
                      On iOS? We haven't forgotten you.
                    </p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#4a4f6a;">
                      MetroPaws is Android-only today, and we know that leaves some of you
                      waiting. We've already mapped out what the iOS version needs and that
                      work is underway — you're a big part of why it's next on our list.
                      When the App Store listing goes live, you'll hear it here first.
                      Nothing for you to do in the meantime.
                    </p>
                  </td></tr>
                </table>
              </td></tr>
              <!-- Sign-off -->
              <tr><td style="padding:26px 32px 30px;font-family:Arial,Helvetica,sans-serif;">
                <p style="margin:0 0 4px;font-size:15px;line-height:1.65;color:#4a4f6a;">
                  Maraming salamat sa tiwala — see you in the app.
                </p>
                <p style="margin:0;font-size:15px;font-weight:bold;color:#263258;">
                  The MetroPaws Team
                </p>
              </td></tr>"""

    html_body = _branded_shell(
        preheader=(
            "The MetroPaws app is now on Google Play — and here's where we are with iOS."
        ),
        card_rows=card_rows,
        footer_note=copy.footer_note,
    )
    return copy.subject, html_body


def send_app_launch_email(
    to_email: str,
    first_name: str,
    audience: str,
    from_name: str = None,
):
    """Send one member/reservation the Android launch announcement.

    Raises on failure so the broadcast script can log the address and keep going.
    """
    subject, html_body = build_app_launch_email(first_name, audience)
    _send_email(to_email, subject, html_body, from_name=from_name)
