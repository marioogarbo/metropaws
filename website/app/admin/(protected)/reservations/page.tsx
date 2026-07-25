import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ReservationsTable } from "@/components/admin/reservations-table";
import { ExportButton } from "@/components/admin/export-button";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

export interface Reservation {
  id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string | null;
  barangay: string;
  message: string | null;
  status: "pending" | "approved" | "rejected";
  admin_notes: string | null;
  created_at: string;
}

interface StatPillProps {
  label: string;
  count: number;
  highlighted?: boolean;
}

function StatPill({ label, count, highlighted }: StatPillProps) {
  if (highlighted) {
    return (
      <div className="flex items-baseline gap-1.5 px-3.5 py-2 rounded-lg border bg-[oklch(0.93_0.025_80)] border-[oklch(0.87_0.040_80)]">
        <span className="text-base font-bold tabular-nums leading-none text-[oklch(0.40_0.060_82)]">
          {count}
        </span>
        <span className="text-xs font-medium text-[oklch(0.52_0.055_82)]">{label}</span>
      </div>
    );
  }
  return (
    <div className="flex items-baseline gap-1.5 px-3.5 py-2 rounded-lg border bg-[oklch(0.97_0.008_80)] border-[oklch(0.91_0.010_258)]">
      <span className="text-base font-bold tabular-nums leading-none text-[oklch(0.24_0.055_258)]">
        {count}
      </span>
      <span className="text-xs font-medium text-[oklch(0.55_0.018_258)]">{label}</span>
    </div>
  );
}

export default async function AdminReservationsPage() {
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;

  if (!token) redirect("/admin/login");

  let reservations: Reservation[] = [];
  try {
    const res = await fetch(`${BACKEND_URL}/admin/founding-reservations`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    if (res.ok) {
      reservations = await res.json();
    }
  } catch {
    // surface empty state
  }

  const pending = reservations.filter((r) => r.status === "pending").length;
  const approved = reservations.filter((r) => r.status === "approved").length;
  const rejected = reservations.filter((r) => r.status === "rejected").length;

  return (
    <main className="max-w-7xl mx-auto px-6 py-10">
      <header className="mb-8">
        <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-5">
          <div>
            <p className="text-[oklch(0.72_0.115_82)] text-xs font-semibold tracking-widest uppercase mb-2">
              Founding 50
            </p>
            <h1 className="text-[oklch(0.24_0.055_258)] text-2xl font-bold tracking-tight leading-tight">
              Reservations
            </h1>
          </div>
          <div className="flex flex-col items-start sm:items-end gap-3">
            <div className="flex gap-2.5 flex-wrap items-start">
              <StatPill label="Total" count={reservations.length} />
              <StatPill label="Pending" count={pending} highlighted={pending > 0} />
              <StatPill label="Approved" count={approved} />
              <StatPill label="Rejected" count={rejected} />
            </div>
            <ExportButton resource="reservations" />
          </div>
        </div>
      </header>

      <ReservationsTable reservations={reservations} />
    </main>
  );
}
