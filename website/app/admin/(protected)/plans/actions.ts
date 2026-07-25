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

function parseNonNegativeInt(raw: string): number | null {
  if (!raw || !raw.trim()) return null;
  const n = parseInt(raw.trim(), 10);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

const MAX_WALLET_CENTAVOS = 100_000_000; // ₱1,000,000

/**
 * Parse an admin-typed wallet amount (pesos; may contain commas / decimals)
 * into integer centavos. Empty string means ₱0 (no wallet). `label` names the
 * pool in error messages (e.g. "Preventive Wellness Wallet").
 */
function parseWalletCentavos(
  raw: string,
  label = "Benefit Wallet",
): number | { error: string } {
  const pesoStr = String(raw ?? "").replace(/[,\s]/g, "");
  const pesos = pesoStr === "" ? 0 : Number(pesoStr);
  if (!Number.isFinite(pesos) || pesos < 0) {
    return { error: `The ${label} must be an amount of ₱0 or greater.` };
  }
  const centavos = Math.round(pesos * 100);
  if (centavos > MAX_WALLET_CENTAVOS) {
    return { error: `The ${label} exceeds the ₱1,000,000 maximum.` };
  }
  return centavos;
}

function parseFeatures(raw: string): string[] | { error: string } {
  if (!raw) return [];
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) return { error: "Invalid features format." };
    return (parsed as unknown[])
      .filter((f): f is string => typeof f === "string")
      .map((f) => f.trim())
      .filter(Boolean);
  } catch {
    return { error: "Could not parse features." };
  }
}

async function safeFetch(url: string, options: RequestInit): Promise<Response | null> {
  try {
    return await fetch(url, options);
  } catch {
    return null;
  }
}

function apiErrorMessage(res: Response, detail: string | undefined, fallback: string): string {
  if (res.status === 401) return "Session expired. Please log in again.";
  return detail ?? fallback;
}

export async function createPlanAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const name = (formData.get("name") as string)?.trim();
  if (!name) return { error: "Plan name is required." };

  const price = parseNonNegativeInt(formData.get("price") as string);
  if (price === null) return { error: "Annual price must be a valid number (0 or greater)." };

  const priceMonthlyRaw = (formData.get("price_monthly") as string)?.trim();
  const priceMonthly = priceMonthlyRaw ? parseNonNegativeInt(priceMonthlyRaw) : null;
  if (priceMonthlyRaw && priceMonthly === null)
    return { error: "Monthly price must be a valid number (0 or greater)." };

  const featuresResult = parseFeatures(formData.get("features") as string);
  if ("error" in featuresResult) return { error: featuresResult.error };

  const walletResult = parseWalletCentavos(
    formData.get("reimbursement_wallet") as string,
    "Preventive Wellness Wallet",
  );
  if (typeof walletResult !== "number") return { error: walletResult.error };

  const emergencyResult = parseWalletCentavos(
    formData.get("emergency_wallet") as string,
    "Emergency Wallet",
  );
  if (typeof emergencyResult !== "number") return { error: emergencyResult.error };

  const sortOrderRaw = (formData.get("sort_order") as string) || "0";
  const sortOrder = parseNonNegativeInt(sortOrderRaw) ?? 0;

  const body = {
    name,
    price,
    price_monthly: priceMonthly,
    tagline: (formData.get("tagline") as string)?.trim() || null,
    features: featuresResult,
    is_featured: formData.get("is_featured") === "true",
    is_active: formData.get("is_active") === "true",
    sort_order: sortOrder,
    reimbursement_wallet_centavos: walletResult,
    emergency_wallet_centavos: emergencyResult,
  };

  const res = await safeFetch(`${BACKEND_URL}/admin/plans`, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...authHeader(token) },
    body: JSON.stringify(body),
  });

  if (!res) return { error: "Network error. Check your connection and try again." };

  if (!res.ok) {
    const err = await res.json().catch(() => ({})) as { detail?: string };
    return { error: apiErrorMessage(res, err.detail, "Failed to create plan.") };
  }

  revalidatePath("/admin/plans");
  return { error: null };
}

export async function updatePlanAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const planId = (formData.get("planId") as string)?.trim();
  if (!planId) return { error: "Plan ID is missing." };

  const name = (formData.get("name") as string)?.trim();
  if (!name) return { error: "Plan name is required." };

  const price = parseNonNegativeInt(formData.get("price") as string);
  if (price === null) return { error: "Annual price must be a valid number (0 or greater)." };

  const priceMonthlyRaw = (formData.get("price_monthly") as string)?.trim();
  const priceMonthly = priceMonthlyRaw ? parseNonNegativeInt(priceMonthlyRaw) : null;
  if (priceMonthlyRaw && priceMonthly === null)
    return { error: "Monthly price must be a valid number (0 or greater)." };

  const featuresResult = parseFeatures(formData.get("features") as string);
  if ("error" in featuresResult) return { error: featuresResult.error };

  const walletResult = parseWalletCentavos(
    formData.get("reimbursement_wallet") as string,
    "Preventive Wellness Wallet",
  );
  if (typeof walletResult !== "number") return { error: walletResult.error };

  const emergencyResult = parseWalletCentavos(
    formData.get("emergency_wallet") as string,
    "Emergency Wallet",
  );
  if (typeof emergencyResult !== "number") return { error: emergencyResult.error };

  const sortOrderRaw = (formData.get("sort_order") as string) || "0";
  const sortOrder = parseNonNegativeInt(sortOrderRaw) ?? 0;

  const body = {
    name,
    price,
    price_monthly: priceMonthly,
    tagline: (formData.get("tagline") as string)?.trim() || null,
    features: featuresResult,
    is_featured: formData.get("is_featured") === "true",
    is_active: formData.get("is_active") === "true",
    sort_order: sortOrder,
    reimbursement_wallet_centavos: walletResult,
    emergency_wallet_centavos: emergencyResult,
  };

  const res = await safeFetch(`${BACKEND_URL}/admin/plans/${planId}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", ...authHeader(token) },
    body: JSON.stringify(body),
  });

  if (!res) return { error: "Network error. Check your connection and try again." };

  if (!res.ok) {
    const err = await res.json().catch(() => ({})) as { detail?: string };
    return { error: apiErrorMessage(res, err.detail, "Failed to update plan.") };
  }

  revalidatePath("/admin/plans");
  return { error: null };
}

export async function deletePlanAction(planId: string): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  if (!planId?.trim()) return { error: "Plan ID is missing." };

  const res = await safeFetch(`${BACKEND_URL}/admin/plans/${planId}`, {
    method: "DELETE",
    headers: authHeader(token),
  });

  if (!res) return { error: "Network error. Check your connection and try again." };

  if (!res.ok && res.status !== 204) {
    const err = await res.json().catch(() => ({})) as { detail?: string };
    return { error: apiErrorMessage(res, err.detail, "Failed to delete plan.") };
  }

  revalidatePath("/admin/plans");
  return { error: null };
}
