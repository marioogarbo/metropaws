"""Password reset link email."""

from app.email_utils.layout import _branded_shell
from app.email_utils.transport import _send_email


def send_reset_email(to_email: str, reset_link: str, from_name: str = "MetroPaws"):
    subject = "Reset Your MetroPaws Password"

    html_body = _branded_shell(
        preheader="Reset your MetroPaws password — this secure link expires in 1 hour.",
        card_rows=f"""
              <!-- Body -->
              <tr><td style="padding:36px 32px 8px;font-family:Arial,Helvetica,sans-serif;color:#1a1e32;">
                <h1 style="margin:0 0 12px;font-size:22px;font-weight:bold;color:#263258;">
                  Reset your password
                </h1>
                <p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:#4a4f6a;">
                  Hi there, we received a request to reset your MetroPaws password.
                  Tap the button below to choose a new one.
                </p>
                <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 26px;">
                  <tr><td style="border-radius:12px;background:#263258;">
                    <a href="{reset_link}"
                       style="display:inline-block;padding:14px 34px;font-family:Arial,sans-serif;
                              font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none;
                              border-radius:12px;">
                      Reset Password
                    </a>
                  </td></tr>
                </table>
                <p style="margin:0 0 8px;font-size:13px;line-height:1.6;color:#8b8fa8;">
                  This link expires in <strong style="color:#4a4f6a;">1 hour</strong>. If you didn't
                  request a password reset, you can safely ignore this email — your password won't change.
                </p>
              </td></tr>""",
    )

    try:
        _send_email(to_email, subject, html_body, from_name=from_name)
    except Exception as e:
        raise Exception(f"Failed to send email: {str(e)}") from e
