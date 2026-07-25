import { Suspense } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { PlansTable } from "@/components/admin/plans-table";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

export interface PlanService {
  id: string;
  service_type: {
    id: string;
    name: string;
    description: string | null;
    icon: string;
  };
  sessions: number;
  reimbursement_cap_centavos: number;
}

export interface Plan {
  id: string;
  name: string;
  price: number;
  price_monthly: number | null;
  tagline: string | null;
  features: string[];
  is_featured: boolean;
  is_active: boolean;
  sort_order: number;
  // Two annual reimbursement pools in centavos. Preventive Wellness funds all
  // non-emergency claims; Emergency funds "Emergency"-category claims.
  reimbursement_wallet_centavos: number;
  emergency_wallet_centavos: number;
  plan_services: PlanService[];
}

async function PlansContent({ token }: { token: string }) {
  let plans: Plan[] = [];
  let fetchError = false;
  let unauthorized = false;
  try {
    const plansRes = await fetch(`${BACKEND_URL}/admin/plans`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    if (plansRes.status === 401) {
      unauthorized = true;
    } else if (plansRes.ok) {
      plans = await plansRes.json();
    } else {
      fetchError = true;
    }
  } catch {
    fetchError = true;
  }

  // redirect() throws — it must run OUTSIDE the try/catch or the catch
  // swallows it and the page shows "Could not load plans" instead of login.
  if (unauthorized) redirect("/admin/login");

  return <PlansTable plans={plans} fetchError={fetchError} />;
}

function PlansSkeleton() {
  return (
    <div className="animate-pulse">
      <div className="mb-8">
        <div className="h-3 w-16 bg-[oklch(0.88_0.010_258)] rounded mb-2" />
        <div className="flex items-center justify-between">
          <div className="h-7 w-52 bg-[oklch(0.88_0.010_258)] rounded" />
          <div className="h-7 w-24 bg-[oklch(0.88_0.010_258)] rounded" />
        </div>
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            className="rounded-xl bg-[oklch(0.99_0.005_80)] border border-[oklch(0.88_0.010_258)] p-5 space-y-4"
          >
            <div className="flex gap-2">
              <div className="h-5 w-14 bg-[oklch(0.88_0.010_258)] rounded" />
              <div className="h-5 w-12 bg-[oklch(0.88_0.010_258)] rounded" />
            </div>
            <div className="h-5 w-28 bg-[oklch(0.88_0.010_258)] rounded" />
            <div className="h-16 bg-[oklch(0.94_0.015_75)] rounded-lg" />
            <div className="space-y-2 pt-1">
              <div className="h-2.5 w-full bg-[oklch(0.88_0.010_258)] rounded" />
              <div className="h-2.5 w-5/6 bg-[oklch(0.88_0.010_258)] rounded" />
              <div className="h-2.5 w-4/6 bg-[oklch(0.88_0.010_258)] rounded" />
            </div>
            <div className="pt-2 flex justify-end gap-2 border-t border-[oklch(0.92_0.010_258)]">
              <div className="h-7 w-16 bg-[oklch(0.88_0.010_258)] rounded-lg" />
              <div className="h-7 w-16 bg-[oklch(0.88_0.010_258)] rounded-lg" />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

export default async function AdminPlansPage() {
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;

  if (!token) redirect("/admin/login");

  return (
    <main className="max-w-7xl mx-auto px-6 py-10">
      <Suspense fallback={<PlansSkeleton />}>
        <PlansContent token={token} />
      </Suspense>
    </main>
  );
}
