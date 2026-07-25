"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

async function getToken(): Promise<string | null> {
  const cookieStore = await cookies();
  return cookieStore.get("admin_token")?.value ?? null;
}

function authHeader(token: string) {
  return { Authorization: `Bearer ${token}` };
}

export type ActionState = { error: string | null };

/** Approve / reject / request-info / set-under-review on a claim. */
export async function reviewReimbursementAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const id = formData.get("reimbursementId") as string;
  const status = formData.get("status") as string;
  const adminNotes = formData.get("admin_notes") as string | null;
  const approvedRaw = formData.get("approved_amount_centavos") as string | null;

  const body: Record<string, unknown> = { status };
  if (adminNotes !== null) body.admin_notes = adminNotes;
  if (status === "approved" && approvedRaw) {
    body.approved_amount_centavos = parseInt(approvedRaw, 10);
  }

  const res = await fetch(`${BACKEND_URL}/admin/reimbursements/${id}/review`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", ...authHeader(token) },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to update the claim." };
  }

  revalidatePath("/admin/reimbursements");
  return { error: null };
}

/** Mark an approved claim as paid (offline payout released). */
export async function markReimbursementPaidAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const id = formData.get("reimbursementId") as string;
  const adminNotes = formData.get("admin_notes") as string | null;
  const paymentReference = formData.get("payment_reference") as string | null;

  if (!paymentReference || !paymentReference.trim()) {
    return { error: "A payment reference is required to mark paid." };
  }

  const body: Record<string, unknown> = { payment_reference: paymentReference.trim() };
  if (adminNotes !== null && adminNotes !== "") body.admin_notes = adminNotes;

  const res = await fetch(`${BACKEND_URL}/admin/reimbursements/${id}/mark-paid`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", ...authHeader(token) },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to mark the claim as paid." };
  }

  revalidatePath("/admin/reimbursements");
  return { error: null };
}
