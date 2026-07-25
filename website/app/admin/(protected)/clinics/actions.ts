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

export async function createClinicAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const body: Record<string, unknown> = {
    email: formData.get("email"),
    password: formData.get("password"),
    clinic_name: formData.get("clinic_name"),
  };

  const phone = formData.get("phone");
  if (phone && phone !== "") body.phone = phone;

  const address = formData.get("address");
  if (address && address !== "") body.address = address;

  const res = await fetch(`${BACKEND_URL}/admin/clinic-partners`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...authHeader(token),
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to create clinic." };
  }

  revalidatePath("/admin/clinics");
  return { error: null };
}

export async function updateClinicAction(
  clinicId: string,
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const clinicName = (formData.get("clinic_name") as string)?.trim();
  if (!clinicName) return { error: "Clinic name is required." };

  const body: Record<string, unknown> = {
    clinic_name: clinicName,
  };

  const phone = formData.get("phone");
  body.phone = phone && phone !== "" ? phone : null;

  const address = formData.get("address");
  body.address = address && address !== "" ? address : null;

  const res = await fetch(`${BACKEND_URL}/admin/clinic-partners/${clinicId}`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
      ...authHeader(token),
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to update clinic." };
  }

  revalidatePath("/admin/clinics");
  return { error: null };
}

export async function deleteClinicAction(clinicId: string): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const res = await fetch(`${BACKEND_URL}/admin/clinic-partners/${clinicId}`, {
    method: "DELETE",
    headers: authHeader(token),
  });

  if (!res.ok && res.status !== 204) {
    const err = await res.json().catch(() => ({}));
    return { error: err?.detail ?? "Failed to delete clinic." };
  }

  revalidatePath("/admin/clinics");
  return { error: null };
}
