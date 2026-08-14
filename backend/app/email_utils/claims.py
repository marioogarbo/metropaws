"""Reimbursement claim status updates. Amounts arrive in centavos."""

from app.email_utils.transport import _send_email


def _peso(centavos):
    if centavos is None:
        return None
    return f"₱{centavos / 100:,.2f}"


def send_claim_status_email(
    to_email: str,
    member_name: str,
    status: str,
    service_name: str,
    claimed_centavos: int,
    approved_centavos=None,
    admin_note=None,
    from_name: str = "MetroPaws",
    payout_target: str = "member",
    provider_name: str | None = None,
):
    """Notify a member that their reimbursement claim changed status.

    Sent on approved / rejected / needs_info / paid. Includes the admin's note so
    "receipt unclear, please resubmit" reaches the member's inbox. When
    payout_target is "provider", the copy reflects that MetroPaws is paying the
    named provider directly rather than reimbursing the member.
    """
    is_provider_target = payout_target == "provider" and provider_name

    headline = {
        "approved":   "Your payment request was approved" if is_provider_target else "Your reimbursement claim was approved",
        "paid":       f"We paid {provider_name}" if is_provider_target else "Your reimbursement has been released",
        "rejected":   "Update on your claim",
        "needs_info": "We need clearer info for your claim",
    }.get(status, "Update on your claim")

    if is_provider_target:
        intro = {
            "approved":   f"Good news, {member_name}! Your request to pay <b>{provider_name}</b> directly for <b>{service_name}</b> has been approved.",
            "paid":       f"Hi {member_name}, we've paid <b>{provider_name}</b> for your <b>{service_name}</b> — nothing more to pay at your appointment.",
            "rejected":   f"Hi {member_name}, your request to pay <b>{provider_name}</b> directly for <b>{service_name}</b> was not approved.",
            "needs_info": f"Hi {member_name}, we need clearer or more complete info before we can approve paying <b>{provider_name}</b> for your <b>{service_name}</b> appointment.",
        }.get(status, f"Hi {member_name}, there's an update on your <b>{service_name}</b> request.")
    else:
        intro = {
            "approved":   f"Good news, {member_name}! Your claim for <b>{service_name}</b> has been approved.",
            "paid":       f"Hi {member_name}, your reimbursement for <b>{service_name}</b> has been released.",
            "rejected":   f"Hi {member_name}, your claim for <b>{service_name}</b> was not approved.",
            "needs_info": f"Hi {member_name}, we need a clearer or more complete receipt for your <b>{service_name}</b> claim before we can continue.",
        }.get(status, f"Hi {member_name}, there's an update on your <b>{service_name}</b> claim.")

    rows = [("Service", service_name), ("Amount claimed", _peso(claimed_centavos))]
    if approved_centavos is not None and status in ("approved", "paid"):
        rows.append(("Amount approved", _peso(approved_centavos)))
    rows.append(("Status", status.replace("_", " ").title()))

    detail_rows = "".join(
        f'<tr><td style="padding:6px 12px;color:#666;">{label}</td>'
        f'<td style="padding:6px 12px;font-weight:600;">{value}</td></tr>'
        for label, value in rows if value is not None
    )

    note_block = ""
    if admin_note:
        note_block = (
            '<div style="margin:20px 0;padding:14px 16px;background:#fbf6e9;'
            'border-left:4px solid #b89a3e;border-radius:6px;">'
            f'<b>Note from MetroPaws:</b><br/>{admin_note}</div>'
        )

    resubmit_hint = ""
    if status == "needs_info":
        resubmit_hint = (
            '<p>Please open the MetroPaws app, go to your claim, and tap '
            '<b>Resubmit</b> to upload a clearer receipt.</p>'
        )

    html_body = f"""
    <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto;">
          <h2 style="color: #1a2245;">{headline}</h2>
          <p>{intro}</p>
          <table style="border-collapse:collapse;margin:16px 0;">{detail_rows}</table>
          {note_block}
          {resubmit_hint}
          <p style="color:#666;font-size:14px;">You can view this claim anytime in the MetroPaws app.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
          <p style="color: #999; font-size: 12px;">© 2026 MetroPaws Wellness Club Philippines, Inc.</p>
        </div>
      </body>
    </html>
    """

    _send_email(to_email, headline, html_body, from_name=from_name)
