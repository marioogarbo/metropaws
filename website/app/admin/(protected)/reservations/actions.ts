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

export async function updateReservationStatusAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const reservationId = formData.get("reservationId") as string;
  const status = formData.get("status") as string;
  const adminNotes = formData.get("admin_notes") as string | null;

  const body: Record<string, unknown> = { status };
  if (adminNotes !== null) body.admin_notes = adminNotes;

  const res = await fetch(
    `${BACKEND_URL}/admin/founding-reservations/${reservationId}/status`,
    {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        ...authHeader(token),
      },
      body: JSON.stringify(body),
    },
  );

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to update reservation." };
  }

  revalidatePath("/admin/reservations");
  return { error: null };
}

export async function deleteReservationAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const reservationId = formData.get("reservationId") as string;

  const res = await fetch(
    `${BACKEND_URL}/admin/founding-reservations/${reservationId}`,
    {
      method: "DELETE",
      headers: authHeader(token),
    },
  );

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to delete reservation." };
  }

  revalidatePath("/admin/reservations");
  return { error: null };
}
