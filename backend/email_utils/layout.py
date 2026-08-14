"""The shared branded shell: logo header, content card, footer.

Build new templates on ``_branded_shell`` rather than re-inlining the markup —
the claim-status and receipt templates predate it and still carry their own
copies, which is why a styling change currently has to be made three times.
"""


# Email clients can't read repo assets, so the logo is pulled from the marketing
# site's public folder over HTTPS.
_LOGO_WHITE_URL = "https://www.metropaws.ph/logo-full-white-metro.png"


_SUPPORT_EMAIL = "csr@metropaws.ph"


def _branded_shell(preheader: str, card_rows: str, footer_note: str = "") -> str:
    """Wrap ``card_rows`` in the MetroPaws email layout.

    ``card_rows`` is one or more ``<tr>`` blocks, placed as rows of the 600px
    card between the navy logo header and the footer. ``preheader`` is the hidden
    line inbox lists preview beside the subject; ``footer_note`` adds an optional
    closing line (e.g. why the recipient is getting this). Tables and inline
    styles throughout, because Outlook and Gmail strip stylesheets.
    """
    note_line = ""
    if footer_note:
        note_line = f"""
                <p style="margin:10px 0 0;font-size:12px;color:#a0a4bd;">
                  {footer_note}
                </p>"""

    return f"""
    <!DOCTYPE html>
    <html>
      <body style="margin:0;padding:0;background:#f4f5f7;">
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;">
          {preheader}
        </div>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
               style="background:#f4f5f7;padding:32px 12px;">
          <tr><td align="center">
            <table role="presentation" width="600" cellpadding="0" cellspacing="0"
                   style="max-width:600px;width:100%;background:#ffffff;border-radius:16px;
                          overflow:hidden;box-shadow:0 1px 4px rgba(26,34,69,0.08);">
              <!-- Brand header -->
              <tr><td style="background:#263258;padding:26px 32px;text-align:center;">
                <img src="{_LOGO_WHITE_URL}"
                     alt="MetroPaws" height="36"
                     style="height:36px;display:inline-block;border:0;outline:none;">
              </td></tr>
              {card_rows}
              <!-- Footer -->
              <tr><td style="padding:22px 32px 28px;border-top:1px solid #eef0f8;
                             font-family:Arial,Helvetica,sans-serif;">
                <p style="margin:0;font-size:12px;color:#a0a4bd;">
                  © 2026 MetroPaws Wellness Club Philippines, Inc.
                </p>
                <p style="margin:4px 0 0;font-size:12px;color:#a0a4bd;">
                  Need help? Reply to this email or contact {_SUPPORT_EMAIL}
                </p>{note_line}
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body>
    </html>
    """
