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

export interface FAQ {
  id: string;
  question: string;
  answer: string;
  sort_order: number;
  is_published: boolean;
}

export async function fetchFaqsAction(): Promise<FAQ[]> {
  const token = await getToken();
  if (!token) return [];

  try {
    const res = await fetch(`${BACKEND_URL}/admin/faqs`, {
      headers: authHeader(token),
      cache: "no-store",
    });
    if (!res.ok) return [];
    return (await res.json()) as FAQ[];
  } catch {
    return [];
  }
}

export async function createFaqAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const question = (formData.get("question") as string)?.trim();
  if (!question) return { error: "Question is required." };

  const answer = (formData.get("answer") as string)?.trim();
  if (!answer) return { error: "Answer is required." };

  const sortOrderRaw = (formData.get("sort_order") as string) || "0";
  const sortOrder = 0;

  const isPublished = formData.get("is_published") === "true";

  try {
    const res = await fetch(`${BACKEND_URL}/admin/faqs`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...authHeader(token),
      },
      body: JSON.stringify({
        question,
        answer,
        sort_order: sortOrder,
        is_published: isPublished,
      }),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      const body = await res.json().catch(() => null);
      return {
        error: (body as { detail?: string } | null)?.detail ?? "Failed to create FAQ.",
      };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath("/admin/faqs");
  return { error: null };
}

export async function updateFaqAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const id = formData.get("id") as string;
  if (!id) return { error: "Missing FAQ ID." };

  const question = (formData.get("question") as string)?.trim();
  if (!question) return { error: "Question is required." };

  const answer = (formData.get("answer") as string)?.trim();
  if (!answer) return { error: "Answer is required." };

  const isPublished = formData.get("is_published") === "true";

  try {
    const res = await fetch(`${BACKEND_URL}/admin/faqs/${id}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        ...authHeader(token),
      },
      body: JSON.stringify({
        question,
        answer,
        is_published: isPublished,
      }),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      if (res.status === 404) return { error: "FAQ not found." };
      const body = await res.json().catch(() => null);
      return {
        error: (body as { detail?: string } | null)?.detail ?? "Failed to update FAQ.",
      };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath("/admin/faqs");
  return { error: null };
}

export async function toggleFaqPublishedAction(
  id: string,
  is_published: boolean,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  try {
    const res = await fetch(`${BACKEND_URL}/admin/faqs/${id}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        ...authHeader(token),
      },
      body: JSON.stringify({ is_published }),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      return { error: "Failed to update FAQ." };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath("/admin/faqs");
  return { error: null };
}

export async function reorderFaqsAction(ids: string[]): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  try {
    const res = await fetch(`${BACKEND_URL}/admin/faqs/reorder`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        ...authHeader(token),
      },
      body: JSON.stringify({ ids }),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      return { error: "Failed to save new order." };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath("/admin/faqs");
  return { error: null };
}

export async function deleteFaqAction(id: string): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  try {
    const res = await fetch(`${BACKEND_URL}/admin/faqs/${id}`, {
      method: "DELETE",
      headers: authHeader(token),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      if (res.status === 404) return { error: "FAQ not found." };
      return { error: "Failed to delete FAQ." };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath("/admin/faqs");
  return { error: null };
}
