import { Suspense } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { Megaphone } from "lucide-react";
import { PromosTable } from "@/components/admin/promos-table";
import type { Promo } from "./actions";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

async function PromosContent({ token }: { token: string }) {
  let promos: Promo[] = [];
  let fetchError = false;
  let unauthorized = false;

  try {
    const res = await fetch(`${BACKEND_URL}/admin/promos`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    if (res.ok) {
      promos = await res.json();
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

  return <PromosTable promos={promos} fetchError={fetchError} />;
}

function PromosSkeleton() {
  return (
    <div className="animate-pulse">
      <div className="mb-8">
        <div className="h-3 w-16 bg-[oklch(0.88_0.010_258)] rounded mb-2" />
        <div className="flex items-center justify-between">
          <div className="h-7 w-40 bg-[oklch(0.88_0.010_258)] rounded" />
          <div className="h-7 w-24 bg-[oklch(0.88_0.010_258)] rounded" />
        </div>
      </div>
      <div className="space-y-2">
        {[0, 1, 2, 3].map((i) => (
          <div
            key={i}
            className="rounded-xl bg-[oklch(0.99_0.005_80)] border border-[oklch(0.88_0.010_258)] px-5 py-4 flex items-center justify-between"
          >
            <div className="space-y-1.5 flex-1 mr-10">
              <div className="h-3.5 w-2/3 bg-[oklch(0.88_0.010_258)] rounded" />
              <div className="h-2.5 w-1/3 bg-[oklch(0.92_0.010_258)] rounded" />
            </div>
            <div className="flex gap-2">
              <div className="h-6 w-6 bg-[oklch(0.88_0.010_258)] rounded" />
              <div className="h-6 w-6 bg-[oklch(0.88_0.010_258)] rounded" />
              <div className="h-6 w-6 bg-[oklch(0.88_0.010_258)] rounded" />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

export default async function AdminPromosPage() {
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;

  if (!token) redirect("/admin/login");

  return (
    <main className="max-w-4xl mx-auto px-6 py-10">
      <div className="mb-8">
        <div className="flex items-center gap-2 mb-1.5">
          <Megaphone size={15} className="text-[oklch(0.48_0.020_258)]" />
          <p className="text-sm text-[oklch(0.48_0.020_258)] font-semibold uppercase tracking-widest">
            Promos &amp; Events
          </p>
        </div>
        <h1 className="text-2xl font-bold text-[oklch(0.24_0.055_258)] tracking-tight">
          Promos &amp; Events
        </h1>
        <p className="text-sm text-[oklch(0.48_0.020_258)] mt-2">
          What members see on the app&apos;s Events tab — club events and member promos.
        </p>
      </div>

      <Suspense fallback={<PromosSkeleton />}>
        <PromosContent token={token} />
      </Suspense>
    </main>
  );
}
