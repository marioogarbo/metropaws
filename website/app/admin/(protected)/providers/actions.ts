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

function payoutFieldsFromForm(formData: FormData): Record<string, unknown> {
  const body: Record<string, unknown> = {};

  const category = formData.get("category");
  body.category = category && category !== "" ? category : null;

  const phone = formData.get("phone");
  body.phone = phone && phone !== "" ? phone : null;

  const address = formData.get("address");
  body.address = address && address !== "" ? address : null;

  const payoutMethod = formData.get("payout_method");
  body.payout_method = payoutMethod && payoutMethod !== "" ? payoutMethod : null;

  const payoutAccountName = formData.get("payout_account_name");
  body.payout_account_name =
    payoutAccountName && payoutAccountName !== "" ? payoutAccountName : null;

  const payoutAccountNumber = formData.get("payout_account_number");
  body.payout_account_number =
    payoutAccountNumber && payoutAccountNumber !== "" ? payoutAccountNumber : null;

  const payoutBankName = formData.get("payout_bank_name");
  body.payout_bank_name = payoutBankName && payoutBankName !== "" ? payoutBankName : null;

  return body;
}

export async function createProviderAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const name = (formData.get("name") as string)?.trim();
  if (!name) return { error: "Provider name is required." };

  const body: Record<string, unknown> = {
    name,
    is_active: true,
    ...payoutFieldsFromForm(formData),
  };

  const res = await fetch(`${BACKEND_URL}/admin/reimbursement-providers`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...authHeader(token),
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to create provider." };
  }

  revalidatePath("/admin/providers");
  return { error: null };
}

export async function updateProviderAction(
  providerId: string,
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const name = (formData.get("name") as string)?.trim();
  if (!name) return { error: "Provider name is required." };

  const body: Record<string, unknown> = {
    name,
    ...payoutFieldsFromForm(formData),
  };

  const res = await fetch(`${BACKEND_URL}/admin/reimbursement-providers/${providerId}`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
      ...authHeader(token),
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to update provider." };
  }

  revalidatePath("/admin/providers");
  return { error: null };
}

export async function toggleProviderActiveAction(
  providerId: string,
  isActive: boolean,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const res = await fetch(`${BACKEND_URL}/admin/reimbursement-providers/${providerId}`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
      ...authHeader(token),
    },
    body: JSON.stringify({ is_active: isActive }),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to update provider." };
  }

  revalidatePath("/admin/providers");
  return { error: null };
}

export async function deleteProviderAction(providerId: string): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const res = await fetch(`${BACKEND_URL}/admin/reimbursement-providers/${providerId}`, {
    method: "DELETE",
    headers: authHeader(token),
  });

  if (!res.ok && res.status !== 204) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to delete provider." };
  }

  revalidatePath("/admin/providers");
  return { error: null };
}
