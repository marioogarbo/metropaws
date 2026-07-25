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

export interface Promo {
  id: string;
  title: string;
  body: string | null;
  type: "event" | "promo";
  event_date: string | null;
  location: string | null;
  link_url: string | null;
  image_url: string | null;
  is_published: boolean;
  sort_order: number;
  created_at: string;
}

// Admins enter event times as Manila wall-clock in a datetime-local input.
// Stamp the +08:00 offset so the backend stores the correct instant (PH has
// no DST, so the constant offset is safe).
function manilaIso(datetimeLocal: string): string {
  return `${datetimeLocal}:00+08:00`;
}

function promoPayload(formData: FormData) {
  const title = (formData.get("title") as string)?.trim();
  const type = formData.get("type") === "event" ? "event" : "promo";
  const body = (formData.get("body") as string)?.trim() || null;
  const linkUrl = (formData.get("link_url") as string)?.trim() || null;
  const isPublished = formData.get("is_published") === "true";

  const eventDateRaw = (formData.get("event_date") as string)?.trim();
  const location = (formData.get("location") as string)?.trim() || null;

  return {
    title,
    type,
    body,
    link_url: linkUrl,
    is_published: isPublished,
    event_date: type === "event" && eventDateRaw ? manilaIso(eventDateRaw) : null,
    location: type === "event" ? location : null,
  };
}

export async function createPromoAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const payload = promoPayload(formData);
  if (!payload.title) return { error: "Title is required." };

  try {
    const res = await fetch(`${BACKEND_URL}/admin/promos`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...authHeader(token),
      },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      const body = await res.json().catch(() => null);
      return {
        error: (body as { detail?: string } | null)?.detail ?? "Failed to create promo.",
      };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath("/admin/promos");
  return { error: null };
}

export async function updatePromoAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const id = formData.get("id") as string;
  if (!id) return { error: "Missing promo ID." };

  const payload = promoPayload(formData);
  if (!payload.title) return { error: "Title is required." };

  try {
    const res = await fetch(`${BACKEND_URL}/admin/promos/${id}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        ...authHeader(token),
      },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      if (res.status === 404) return { error: "Promo not found." };
      const body = await res.json().catch(() => null);
      return {
        error: (body as { detail?: string } | null)?.detail ?? "Failed to update promo.",
      };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath("/admin/promos");
  return { error: null };
}

export async function togglePromoPublishedAction(
  id: string,
  is_published: boolean,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  try {
    const res = await fetch(`${BACKEND_URL}/admin/promos/${id}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        ...authHeader(token),
      },
      body: JSON.stringify({ is_published }),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      return { error: "Failed to update promo." };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath("/admin/promos");
  return { error: null };
}

export async function deletePromoAction(id: string): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  try {
    const res = await fetch(`${BACKEND_URL}/admin/promos/${id}`, {
      method: "DELETE",
      headers: authHeader(token),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      if (res.status === 404) return { error: "Promo not found." };
      return { error: "Failed to delete promo." };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath("/admin/promos");
  return { error: null };
}
