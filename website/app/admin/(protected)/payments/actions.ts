"use server";

import { cookies } from "next/headers";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

async function getToken(): Promise<string | null> {
  const cookieStore = await cookies();
  return cookieStore.get("admin_token")?.value ?? null;
}

export type ResendInvoiceState = {
  error: string | null;
  email?: string | null;
  invoiceNo?: string;
};

export async function resendInvoiceAction(
  paymentId: string,
): Promise<ResendInvoiceState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  try {
    const res = await fetch(
      `${BACKEND_URL}/admin/payments/${paymentId}/resend-invoice`,
      {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
        cache: "no-store",
      },
    );

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      const body = await res.json().catch(() => null);
      return {
        error:
          (body as { detail?: string } | null)?.detail ??
          "Couldn't send the receipt. Please try again.",
      };
    }

    const body = (await res.json().catch(() => null)) as
      | { email?: string | null; invoice_no?: string }
      | null;
    return { error: null, email: body?.email ?? null, invoiceNo: body?.invoice_no };
  } catch {
    return { error: "Network error. Please try again." };
  }
}
