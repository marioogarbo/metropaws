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

export interface AppSettings {
  require_payment: boolean;
  founding_enrollment_active: boolean;
  member_limit: number;
  founding_claimed: number;
  booking_enabled: boolean;
  direct_provider_payment_enabled: boolean;
  pack_discount_enabled: boolean;
  pack_discount_percent: number;
}

const SETTINGS_DEFAULTS: AppSettings = {
  require_payment: true,
  founding_enrollment_active: false,
  member_limit: 50,
  founding_claimed: 0,
  booking_enabled: false,
  direct_provider_payment_enabled: false,
  pack_discount_enabled: true,
  pack_discount_percent: 15,
};

export async function fetchSettingsAction(): Promise<AppSettings> {
  const token = await getToken();
  if (!token) return SETTINGS_DEFAULTS;

  try {
    const [paymentsRes, foundingRes, mobileConfigRes, packDiscountRes] = await Promise.all([
      fetch(`${BACKEND_URL}/settings/payments-enabled`, {
        headers: authHeader(token),
        cache: "no-store",
      }),
      fetch(`${BACKEND_URL}/settings/founding-50`, {
        headers: authHeader(token),
        cache: "no-store",
      }),
      fetch(`${BACKEND_URL}/settings/mobile-config`, {
        headers: authHeader(token),
        cache: "no-store",
      }),
      fetch(`${BACKEND_URL}/settings/pack-discount`, {
        headers: authHeader(token),
        cache: "no-store",
      }),
    ]);

    const paymentsData = paymentsRes.ok
      ? ((await paymentsRes.json()) as { payments_enabled: boolean })
      : null;

    const foundingData = foundingRes.ok
      ? ((await foundingRes.json()) as { enabled: boolean; limit: number; claimed: number })
      : null;

    const mobileConfigData = mobileConfigRes.ok
      ? ((await mobileConfigRes.json()) as {
          booking_enabled: boolean;
          direct_provider_payment_enabled?: boolean;
        })
      : null;

    const packDiscountData = packDiscountRes.ok
      ? ((await packDiscountRes.json()) as { enabled: boolean; percent: number })
      : null;

    return {
      require_payment: paymentsData?.payments_enabled ?? SETTINGS_DEFAULTS.require_payment,
      founding_enrollment_active:
        foundingData?.enabled ?? SETTINGS_DEFAULTS.founding_enrollment_active,
      member_limit: foundingData?.limit ?? SETTINGS_DEFAULTS.member_limit,
      founding_claimed: foundingData?.claimed ?? SETTINGS_DEFAULTS.founding_claimed,
      booking_enabled:
        mobileConfigData?.booking_enabled ?? SETTINGS_DEFAULTS.booking_enabled,
      direct_provider_payment_enabled:
        mobileConfigData?.direct_provider_payment_enabled ??
        SETTINGS_DEFAULTS.direct_provider_payment_enabled,
      pack_discount_enabled:
        packDiscountData?.enabled ?? SETTINGS_DEFAULTS.pack_discount_enabled,
      pack_discount_percent:
        packDiscountData?.percent ?? SETTINGS_DEFAULTS.pack_discount_percent,
    };
  } catch {
    return SETTINGS_DEFAULTS;
  }
}

export async function updatePaymentGateAction(
  enabled: boolean,
): Promise<{ error: string | null }> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const res = await fetch(`${BACKEND_URL}/admin/settings/payments-enabled`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", ...authHeader(token) },
    body: JSON.stringify({ payments_enabled: enabled }),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: (err as { detail?: string })?.detail ?? "Failed to save." };
  }

  revalidatePath("/admin/settings");
  return { error: null };
}

export async function updateBookingEnabledAction(
  enabled: boolean,
): Promise<{ error: string | null }> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const res = await fetch(`${BACKEND_URL}/admin/settings/booking-enabled`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", ...authHeader(token) },
    body: JSON.stringify({ booking_enabled: enabled }),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: (err as { detail?: string })?.detail ?? "Failed to save." };
  }

  revalidatePath("/admin/settings");
  return { error: null };
}

export async function updateDirectProviderPaymentAction(
  enabled: boolean,
): Promise<{ error: string | null }> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const res = await fetch(`${BACKEND_URL}/admin/settings/direct-provider-payment`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", ...authHeader(token) },
    body: JSON.stringify({ direct_provider_payment_enabled: enabled }),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: (err as { detail?: string })?.detail ?? "Failed to save." };
  }

  revalidatePath("/admin/settings");
  return { error: null };
}

export async function updatePackDiscountAction(
  patch: { enabled?: boolean; percent?: number },
  current: AppSettings,
): Promise<{ error: string | null }> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const payload = {
    enabled: patch.enabled ?? current.pack_discount_enabled,
    percent: patch.percent ?? current.pack_discount_percent,
  };

  const res = await fetch(`${BACKEND_URL}/admin/settings/pack-discount`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", ...authHeader(token) },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: (err as { detail?: string })?.detail ?? "Failed to save." };
  }

  revalidatePath("/admin/settings");
  return { error: null };
}

export async function updateFounding50Action(
  patch: { enabled?: boolean; limit?: number },
  current: AppSettings,
): Promise<{ error: string | null }> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const payload = {
    enabled: patch.enabled ?? current.founding_enrollment_active,
    limit: patch.limit ?? current.member_limit,
  };

  const res = await fetch(`${BACKEND_URL}/admin/settings/founding-50`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", ...authHeader(token) },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    return { error: (err as { detail?: string })?.detail ?? "Failed to save." };
  }

  revalidatePath("/admin/settings");
  return { error: null };
}
