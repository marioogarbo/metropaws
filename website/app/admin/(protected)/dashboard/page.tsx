import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import {
  fetchFoundingLocationAction,
  fetchDashboardSummaryAction,
  fetchBusinessKpisAction,
  fetchClinicVisitsAction,
} from "@/app/admin/(protected)/dashboard/actions";
import { DashboardKpi } from "@/components/admin/dashboard-kpi";
import { BusinessKpi } from "@/components/admin/business-kpi";
import { TopProvidersChart } from "@/components/admin/top-providers-chart";
import { ClinicDirectory } from "@/components/admin/clinic-directory";
import { FoundingLocationChart } from "@/components/admin/founding-location-chart";
import { ReservationStatusChart } from "@/components/admin/reservation-status-chart";
import { PetSpeciesChart } from "@/components/admin/pet-species-chart";
import {
  FoundingProgressCard,
  RecentReservationsCard,
} from "@/components/admin/dashboard-activity";

export default async function AdminDashboardPage() {
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;
  if (!token) redirect("/admin/login");

  const [summary, locationData, businessKpis, clinicVisits] = await Promise.all([
    fetchDashboardSummaryAction(),
    fetchFoundingLocationAction(),
    fetchBusinessKpisAction(),
    fetchClinicVisitsAction(),
  ]);

  return (
    <main className="max-w-7xl mx-auto px-6 py-10 flex flex-col gap-10">
      {/* Page header */}
      <div className="dash-rise" style={{ animationDelay: "0ms" }}>
        <p
          className="text-xs font-semibold uppercase tracking-widest mb-1"
          style={{ color: "oklch(0.72 0.115 82)" }}
        >
          Admin
        </p>
        <div className="flex items-baseline gap-4">
          <h1
            className="font-semibold tracking-tight"
            style={{ color: "oklch(0.24 0.055 258)", fontSize: "22px" }}
          >
            Dashboard
          </h1>
        </div>
      </div>

      {/* Business KPIs — the management view */}
      <div className="flex flex-col gap-4">
        <div className="dash-rise" style={{ animationDelay: "60ms" }}>
          <BusinessKpi kpis={businessKpis} />
        </div>
        <div className="dash-rise" style={{ animationDelay: "90ms" }}>
          <TopProvidersChart data={clinicVisits.slice(0, 10)} />
        </div>
        <div className="dash-rise" style={{ animationDelay: "120ms" }}>
          <ClinicDirectory clinics={clinicVisits} />
        </div>
      </div>

      {/* Founding 50 campaign — launch tracking */}
      <div className="flex flex-col gap-6">
        <div className="dash-rise" style={{ animationDelay: "120ms" }}>
          <h2
            className="font-semibold tracking-tight mb-4"
            style={{ color: "oklch(0.24 0.055 258)", fontSize: "16px" }}
          >
            Founding 50 Campaign
          </h2>
          <DashboardKpi summary={summary} />
        </div>

        {/* Charts row 1: progress + status + species */}
        <div
          className="grid grid-cols-1 md:grid-cols-3 gap-4 dash-rise"
          style={{ animationDelay: "120ms" }}
        >
          <FoundingProgressCard approved={summary.foundingApproved} />
          <ReservationStatusChart summary={summary} />
          <PetSpeciesChart summary={summary} />
        </div>

        {/* Charts row 2: location chart + recent activity */}
        <div
          className="grid grid-cols-1 lg:grid-cols-3 gap-4 dash-rise"
          style={{ animationDelay: "180ms" }}
        >
          <div className="lg:col-span-2">
            <FoundingLocationChart data={locationData} />
          </div>
          <RecentReservationsCard reservations={summary.recentReservations} />
        </div>
      </div>
    </main>
  );
}
