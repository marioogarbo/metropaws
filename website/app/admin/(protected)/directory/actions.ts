"use server";

import { cookies } from "next/headers";
import { revalidateAdminAndPublic } from "@/lib/revalidate";
import { SERVICE_SLUGS, type ServiceSlug } from "@/lib/directory-taxonomy";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

const ADMIN_PATH = "/admin/directory";
const PUBLIC_PATH = "/find-pet-care";

async function getToken(): Promise<string | null> {
  const cookieStore = await cookies();
  return cookieStore.get("admin_token")?.value ?? null;
}

function authHeader(token: string) {
  return { Authorization: `Bearer ${token}` };
}

export type ActionState = { error: string | null };

interface DirectoryPayload {
  name: string;
  services: ServiceSlug[];
  address: string | null;
  phone: string | null;
  email: string | null;
  website: string | null;
  hours: string | null;
  map_url: string | null;
  is_partner: boolean;
  is_published: boolean;
}

function optionalText(formData: FormData, field: string): string | null {
  const value = (formData.get(field) as string | null)?.trim();
  return value ? value : null;
}

/**
 * Admins paste "newalabangvet.com" as often as a full URL, and a bare domain in
 * an href resolves against our own origin, producing a dead link on the public
 * page. Prefix it here rather than asking the operator to remember.
 */
function normalizeUrl(value: string | null): string | null {
  if (!value) return null;
  return /^https?:\/\//i.test(value) ? value : `https://${value}`;
}

function readPayload(formData: FormData): DirectoryPayload | { error: string } {
  const name = (formData.get("name") as string | null)?.trim();
  if (!name) return { error: "Provider name is required." };

  const services = formData
    .getAll("services")
    .filter((value): value is string => typeof value === "string")
    .filter((value): value is ServiceSlug =>
      (SERVICE_SLUGS as string[]).includes(value),
    );
  if (services.length === 0) {
    return { error: "Pick at least one service, or the listing shows under no filter." };
  }

  return {
    name,
    services,
    address: optionalText(formData, "address"),
    phone: optionalText(formData, "phone"),
    email: optionalText(formData, "email"),
    website: normalizeUrl(optionalText(formData, "website")),
    map_url: normalizeUrl(optionalText(formData, "map_url")),
    hours: optionalText(formData, "hours"),
    is_partner: formData.get("is_partner") === "on",
    is_published: formData.get("is_published") === "on",
  };
}

async function send(
  path: string,
  init: RequestInit,
  fallbackError: string,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  try {
    const res = await fetch(`${BACKEND_URL}${path}`, {
      ...init,
      headers: {
        ...(init.body ? { "Content-Type": "application/json" } : {}),
        ...authHeader(token),
      },
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      if (res.status === 404) return { error: "Listing not found. It may already be deleted." };
      const body = await res.json().catch(() => null);
      const detail = (body as { detail?: unknown } | null)?.detail;
      return { error: typeof detail === "string" ? detail : fallbackError };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidateAdminAndPublic(ADMIN_PATH, PUBLIC_PATH);
  return { error: null };
}

export async function createDirectoryProviderAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const payload = readPayload(formData);
  if ("error" in payload) return { error: payload.error };

  return send(
    "/admin/directory",
    { method: "POST", body: JSON.stringify(payload) },
    "Failed to add the listing.",
  );
}

export async function updateDirectoryProviderAction(
  id: string,
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const payload = readPayload(formData);
  if ("error" in payload) return { error: payload.error };

  return send(
    `/admin/directory/${id}`,
    { method: "PUT", body: JSON.stringify(payload) },
    "Failed to save the listing.",
  );
}

export async function toggleDirectoryPublishedAction(
  id: string,
  is_published: boolean,
): Promise<ActionState> {
  return send(
    `/admin/directory/${id}`,
    { method: "PUT", body: JSON.stringify({ is_published }) },
    "Failed to update the listing.",
  );
}

export async function deleteDirectoryProviderAction(
  id: string,
): Promise<ActionState> {
  return send(
    `/admin/directory/${id}`,
    { method: "DELETE" },
    "Failed to delete the listing.",
  );
}
