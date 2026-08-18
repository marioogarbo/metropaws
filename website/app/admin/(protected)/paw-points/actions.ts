"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

const ADMIN_PATH = "/admin/paw-points";

async function getToken(): Promise<string | null> {
  const cookieStore = await cookies();
  return cookieStore.get("admin_token")?.value ?? null;
}

function authHeader(token: string) {
  return { Authorization: `Bearer ${token}` };
}

export type ActionState = { error: string | null };

export interface TopEarner {
  member_id: string;
  first_name: string;
  last_name: string;
  lifetime_earned: number;
  current_balance: number;
}

export interface RewardReach {
  reward_id: string;
  name: string;
  points_required: number;
  members_eligible: number;
}

export interface PawPointsSummary {
  total_issued: number;
  total_redeemed: number;
  total_outstanding: number;
  members_with_points: number;
  top_earners: TopEarner[];
  reward_reach: RewardReach[];
}

export interface MemberBalance {
  member_id: string;
  first_name: string;
  last_name: string;
  email: string | null;
  plan_type: string | null;
  current_balance: number;
  lifetime_earned: number;
  last_activity_at: string | null;
}

export interface LedgerEntry {
  id: string;
  points: number;
  activity_type: string;
  reference_id: string | null;
  notes: string | null;
  created_at: string;
}

export interface MemberLedger {
  balance: { current_balance: number; lifetime_earned: number };
  history: LedgerEntry[];
}

export interface PawReward {
  id: string;
  name: string;
  description: string | null;
  points_required: number;
  reward_type: string;
  is_active: boolean;
  sort_order: number;
}

// ── Reads ────────────────────────────────────────────────────────────────────

export async function fetchMemberBalancesAction(
  search?: string,
): Promise<MemberBalance[]> {
  const token = await getToken();
  if (!token) return [];

  const query = search?.trim()
    ? `?limit=200&search=${encodeURIComponent(search.trim())}`
    : "?limit=200";

  try {
    const res = await fetch(`${BACKEND_URL}/admin/paw-points/members${query}`, {
      headers: authHeader(token),
      cache: "no-store",
    });
    if (!res.ok) return [];
    return (await res.json()) as MemberBalance[];
  } catch {
    return [];
  }
}

export async function fetchMemberLedgerAction(
  memberId: string,
): Promise<MemberLedger | null> {
  const token = await getToken();
  if (!token) return null;

  try {
    const res = await fetch(
      `${BACKEND_URL}/admin/paw-points/members/${memberId}`,
      { headers: authHeader(token), cache: "no-store" },
    );
    if (!res.ok) return null;
    return (await res.json()) as MemberLedger;
  } catch {
    return null;
  }
}

// ── Manual award ─────────────────────────────────────────────────────────────

export async function awardPointsAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const memberId = formData.get("member_id") as string;
  if (!memberId) return { error: "Missing member." };

  const points = Number(formData.get("points"));
  if (!Number.isInteger(points) || points === 0) {
    return { error: "Enter a whole number of points, positive or negative." };
  }

  // A correction has to say why. The ledger is append-only, so this note is the
  // only record of an adjustment that was not earned by member activity.
  const notes = (formData.get("notes") as string)?.trim();
  if (!notes) return { error: "A reason is required for a manual award." };

  try {
    const res = await fetch(`${BACKEND_URL}/admin/paw-points/award`, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...authHeader(token) },
      body: JSON.stringify({ member_id: memberId, points, notes }),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      if (res.status === 404) return { error: "Member not found." };
      const body = await res.json().catch(() => null);
      return {
        error: (body as { detail?: string } | null)?.detail ?? "Failed to award points.",
      };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath(ADMIN_PATH);
  return { error: null };
}

// ── Rewards catalogue ────────────────────────────────────────────────────────

export async function fetchRewardsAction(): Promise<PawReward[]> {
  const token = await getToken();
  if (!token) return [];

  try {
    const res = await fetch(`${BACKEND_URL}/admin/paw-points/rewards`, {
      headers: authHeader(token),
      cache: "no-store",
    });
    if (!res.ok) return [];
    return (await res.json()) as PawReward[];
  } catch {
    return [];
  }
}

function rewardPayloadFrom(formData: FormData) {
  const name = (formData.get("name") as string)?.trim();
  const description = (formData.get("description") as string)?.trim();
  const pointsRequired = Number(formData.get("points_required"));
  const rewardType = (formData.get("reward_type") as string) || "merchandise";
  const sortOrder = Number(formData.get("sort_order") ?? 0);

  return {
    name,
    description: description || null,
    points_required: pointsRequired,
    reward_type: rewardType,
    is_active: formData.get("is_active") === "true",
    sort_order: Number.isFinite(sortOrder) ? sortOrder : 0,
  };
}

function validateReward(payload: { name: string; points_required: number }) {
  if (!payload.name) return "A reward name is required.";
  if (!Number.isInteger(payload.points_required) || payload.points_required <= 0) {
    return "Points required must be a whole number above zero.";
  }
  return null;
}

export async function createRewardAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const payload = rewardPayloadFrom(formData);
  const invalid = validateReward(payload);
  if (invalid) return { error: invalid };

  try {
    const res = await fetch(`${BACKEND_URL}/admin/paw-points/rewards`, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...authHeader(token) },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      const body = await res.json().catch(() => null);
      return {
        error: (body as { detail?: string } | null)?.detail ?? "Failed to create reward.",
      };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath(ADMIN_PATH);
  return { error: null };
}

export async function updateRewardAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  const id = formData.get("id") as string;
  if (!id) return { error: "Missing reward ID." };

  const payload = rewardPayloadFrom(formData);
  const invalid = validateReward(payload);
  if (invalid) return { error: invalid };

  try {
    const res = await fetch(`${BACKEND_URL}/admin/paw-points/rewards/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", ...authHeader(token) },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      if (res.status === 404) return { error: "Reward not found." };
      const body = await res.json().catch(() => null);
      return {
        error: (body as { detail?: string } | null)?.detail ?? "Failed to update reward.",
      };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath(ADMIN_PATH);
  return { error: null };
}

export async function toggleRewardActiveAction(
  id: string,
  isActive: boolean,
): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  try {
    const res = await fetch(`${BACKEND_URL}/admin/paw-points/rewards/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", ...authHeader(token) },
      body: JSON.stringify({ is_active: isActive }),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      return { error: "Failed to update reward." };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath(ADMIN_PATH);
  return { error: null };
}

export async function deleteRewardAction(id: string): Promise<ActionState> {
  const token = await getToken();
  if (!token) return { error: "Not authenticated." };

  try {
    const res = await fetch(`${BACKEND_URL}/admin/paw-points/rewards/${id}`, {
      method: "DELETE",
      headers: authHeader(token),
    });

    if (!res.ok) {
      if (res.status === 401) return { error: "Session expired. Please log in again." };
      if (res.status === 404) return { error: "Reward not found." };
      return { error: "Failed to delete reward." };
    }
  } catch {
    return { error: "Network error. Please try again." };
  }

  revalidatePath(ADMIN_PATH);
  return { error: null };
}
