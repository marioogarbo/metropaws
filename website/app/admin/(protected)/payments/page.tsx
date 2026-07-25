import { Suspense } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { Wallet } from "lucide-react";
import { PaymentsTable } from "@/components/admin/payments-table";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

export interface AdminPayment {
  id: string;
  member_id: string;
  member_first_name: string;
  member_last_name: string;
  member_email: string | null;
  pet_name: string | null;
  plan_name: string | null;
  amount_php: number;
  currency: string;
  status: "pending" | "paid" | "failed" | "expired";
  provider: string;
  provider_payment_id: string | null;
  created_at: string;
  paid_at: string | null;
}

async function PaymentsContent({ token }: { token: string }) {
  let payments: AdminPayment[] = [];
  let fetchError = false;
  let unauthorized = false;

  try {
    const res = await fetch(`${BACKEND_URL}/admin/payments`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    if (res.ok) {
      payments = await res.json();
    } else if (res.status === 401) {
      unauthorized = true;
    } else {
      fetchError = true;
    }
  } catch {
    fetchError = true;
  }

  // redirect() throws — it must run OUTSIDE the try/catch or the catch
  // swallows it and the page shows a fetch error instead of the login page.
  if (unauthorized) redirect("/admin/login");

  return <PaymentsTable payments={payments} fetchError={fetchError} />;
}

function PaymentsSkeleton() {
  return (
    <div className="animate-pulse space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex gap-2">
          {[0, 1, 2, 3].map((i) => (
            <div key={i} className="h-8 w-20 bg-[oklch(0.88_0.010_258)] rounded-lg" />
          ))}
        </div>
        <div className="h-8 w-64 bg-[oklch(0.88_0.010_258)] rounded-lg" />
      </div>
      <div className="rounded-xl border border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] overflow-hidden">
        {[0, 1, 2, 3, 4].map((i) => (
          <div
            key={i}
            className="border-b border-[oklch(0.92_0.010_258)] px-4 py-4 flex items-center gap-4"
          >
            <div className="w-8 h-8 rounded-full bg-[oklch(0.88_0.010_258)] shrink-0" />
            <div className="space-y-1.5 flex-1">
              <div className="h-3.5 w-1/4 bg-[oklch(0.88_0.010_258)] rounded" />
              <div className="h-2.5 w-1/3 bg-[oklch(0.92_0.010_258)] rounded" />
            </div>
            <div className="h-5 w-16 bg-[oklch(0.88_0.010_258)] rounded-full" />
            <div className="h-3.5 w-20 bg-[oklch(0.88_0.010_258)] rounded" />
          </div>
        ))}
      </div>
    </div>
  );
}

export default async function AdminPaymentsPage() {
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;

  if (!token) redirect("/admin/login");

  return (
    <main className="max-w-6xl mx-auto px-6 py-10">
      <div className="mb-8">
        <div className="flex items-center gap-2 mb-1.5">
          <Wallet size={15} className="text-[oklch(0.48_0.020_258)]" />
          <p className="text-sm text-[oklch(0.48_0.020_258)] font-semibold uppercase tracking-widest">
            Revenue
          </p>
        </div>
        <h1 className="text-2xl font-bold text-[oklch(0.24_0.055_258)] tracking-tight">
          Payments
        </h1>
        <p className="text-sm text-[oklch(0.48_0.020_258)] mt-2">
          Every checkout and who made it — use the PayMongo reference to
          cross-check against the PayMongo dashboard.
        </p>
      </div>

      <Suspense fallback={<PaymentsSkeleton />}>
        <PaymentsContent token={token} />
      </Suspense>
    </main>
  );
}
