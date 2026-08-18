import { Suspense } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { PawPrint } from "lucide-react";
import { PawPointsSummaryPanel } from "@/components/admin/paw-points-summary";
import { PawPointsMembersTable } from "@/components/admin/paw-points-members-table";
import { PawPointsRewardsTable } from "@/components/admin/paw-points-rewards-table";
import type {
  MemberBalance,
  PawPointsSummary,
  PawReward,
} from "./actions";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

const EMPTY_SUMMARY: PawPointsSummary = {
  total_issued: 0,
  total_redeemed: 0,
  total_outstanding: 0,
  members_with_points: 0,
  top_earners: [],
  reward_reach: [],
};

async function getJson<T>(
  path: string,
  token: string,
  fallback: T,
): Promise<{ data: T; unauthorized: boolean }> {
  try {
    const res = await fetch(`${BACKEND_URL}${path}`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    if (res.status === 401) return { data: fallback, unauthorized: true };
    if (!res.ok) return { data: fallback, unauthorized: false };
    return { data: (await res.json()) as T, unauthorized: false };
  } catch {
    return { data: fallback, unauthorized: false };
  }
}

async function PawPointsContent({ token }: { token: string }) {
  const [summary, members, rewards] = await Promise.all([
    getJson<PawPointsSummary>("/admin/paw-points/summary", token, EMPTY_SUMMARY),
    getJson<MemberBalance[]>("/admin/paw-points/members?limit=200", token, []),
    getJson<PawReward[]>("/admin/paw-points/rewards", token, []),
  ]);

  // redirect() throws, so it must run outside the fetch helpers' try/catch or
  // the catch swallows it and the page renders empty instead of the login page.
  if (summary.unauthorized || members.unauthorized || rewards.unauthorized) {
    redirect("/admin/login");
  }

  return (
    <div className="space-y-10">
      <PawPointsSummaryPanel summary={summary.data} />
      <PawPointsMembersTable members={members.data} />
      <PawPointsRewardsTable rewards={rewards.data} />
    </div>
  );
}

function PawPointsSkeleton() {
  return (
    <div className="animate-pulse space-y-10">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {[0, 1, 2, 3].map((i) => (
          <div
            key={i}
            className="rounded-xl border px-5 py-4"
            style={{
              borderColor: "oklch(0.88 0.010 258)",
              backgroundColor: "oklch(0.99 0.005 80)",
            }}
          >
            <div className="h-2.5 w-16 rounded bg-[oklch(0.92_0.010_258)] mb-3" />
            <div className="h-6 w-20 rounded bg-[oklch(0.88_0.010_258)]" />
          </div>
        ))}
      </div>
      <div className="space-y-2">
        {[0, 1, 2, 3, 4].map((i) => (
          <div
            key={i}
            className="h-14 rounded-xl border"
            style={{
              borderColor: "oklch(0.88 0.010 258)",
              backgroundColor: "oklch(0.99 0.005 80)",
            }}
          />
        ))}
      </div>
    </div>
  );
}

export default async function AdminPawPointsPage() {
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;

  if (!token) redirect("/admin/login");

  return (
    <main className="max-w-5xl mx-auto px-6 py-10">
      <div className="mb-8">
        <div className="flex items-center gap-2 mb-1.5">
          <PawPrint size={15} className="text-[oklch(0.48_0.020_258)]" />
          <p className="text-sm text-[oklch(0.48_0.020_258)] font-semibold uppercase tracking-widest">
            PawPoints
          </p>
        </div>
        <h1 className="text-2xl font-bold text-[oklch(0.24_0.055_258)] tracking-tight">
          Loyalty &amp; Rewards
        </h1>
        <p className="text-sm text-[oklch(0.48_0.020_258)] mt-2">
          Balances per member, the full ledger behind every point, and the rewards
          catalogue the app reads.
        </p>
      </div>

      <Suspense fallback={<PawPointsSkeleton />}>
        <PawPointsContent token={token} />
      </Suspense>
    </main>
  );
}
