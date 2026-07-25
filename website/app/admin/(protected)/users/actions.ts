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

// ── Members ────────────────────────────────────────────────────────────────

export async function updateMemberAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const memberId = formData.get("memberId") as string;
  const body: Record<string, unknown> = {};

  const fields = ["first_name", "last_name", "phone", "address"] as const;
  for (const field of fields) {
    const val = formData.get(field);
    if (val !== null && val !== "") body[field] = val;
  }

  const isFoundingRaw = formData.get("is_founding");
  if (isFoundingRaw !== null) {
    const isFoundingBool = isFoundingRaw === "true";

    const foundingRes = await fetch(`${BACKEND_URL}/admin/members/${memberId}/founding`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        ...authHeader(token),
      },
      body: JSON.stringify({ is_founding: isFoundingBool }),
    });
    if (!foundingRes.ok) {
      const err = await foundingRes.json().catch(() => ({}));
      return { error: err?.detail ?? "Failed to update founding status." };
    }
  }

  if (Object.keys(body).length > 0) {
    const res = await fetch(`${BACKEND_URL}/admin/members/${memberId}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        ...authHeader(token),
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      return { error: err?.detail ?? "Failed to update member." };
    }
  }

  revalidatePath("/admin/users");
  return { error: null };
}

export async function deleteMemberAction(memberId: string): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const res = await fetch(`${BACKEND_URL}/admin/members/${memberId}`, {
    method: "DELETE",
    headers: authHeader(token),
  });

  if (!res.ok && res.status !== 204) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to delete member." };
  }

  revalidatePath("/admin/users");
  return { error: null };
}

// ── Pets ───────────────────────────────────────────────────────────────────

export async function updatePetAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const memberId = formData.get("memberId") as string;
  const petId = formData.get("petId") as string;

  const body: Record<string, unknown> = {};
  const stringFields = ["name", "species", "breed", "sex", "notes"] as const;
  for (const field of stringFields) {
    const val = formData.get(field);
    if (val !== null && val !== "") body[field] = val;
  }
  const numFields = ["birth_month", "birth_year", "birth_day"] as const;
  for (const field of numFields) {
    const val = formData.get(field);
    if (val !== null && val !== "") body[field] = Number(val);
  }
  const weightVal = formData.get("weight_kg");
  if (weightVal !== null && weightVal !== "") body["weight_kg"] = Number(weightVal);

  const res = await fetch(`${BACKEND_URL}/admin/members/${memberId}/pets/${petId}`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
      ...authHeader(token),
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to update pet." };
  }

  revalidatePath("/admin/users");
  return { error: null };
}

export async function deletePetAction(
  memberId: string,
  petId: string,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const res = await fetch(`${BACKEND_URL}/admin/members/${memberId}/pets/${petId}`, {
    method: "DELETE",
    headers: authHeader(token),
  });

  if (!res.ok && res.status !== 204) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to delete pet." };
  }

  revalidatePath("/admin/users");
  return { error: null };
}
