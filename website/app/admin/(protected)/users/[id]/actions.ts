"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

/**
 * Set one member's direct-to-provider access.
 *
 * `enabled` is tri-state and null is a real value, not "unchanged": it clears
 * the override so the member follows the global switch again.
 */
export async function updateMemberDirectPayAction(
  memberId: string,
  enabled: boolean | null,
  note: string,
): Promise<{ error: string | null }> {
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;
  if (!token) return { error: "Not authenticated." };

  const res = await fetch(`${BACKEND_URL}/admin/members/${memberId}/direct-pay`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      direct_pay_enabled: enabled,
      direct_pay_note: note.trim() || null,
    }),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: (err as { detail?: string })?.detail ?? "Failed to save." };
  }

  revalidatePath(`/admin/users/${memberId}`);
  return { error: null };
}
