import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ReimbursementsTable } from "@/components/admin/reimbursements-table";
import { ExportButton } from "@/components/admin/export-button";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

export interface ReimbursementServiceType {
  id: string;
  name: string;
  description: string | null;
  icon: string;
}

export interface ReimbursementEvent {
  id: string;
  from_status: string | null;
  to_status: string;
  note: string | null;
  created_at: string;
}

export interface ReimbursementMember {
  id: string;
  first_name: string;
  last_name: string;
  email: string | null;
  plan_type: string | null;
  payout_method: string | null;
  payout_account_name: string | null;
  payout_account_number: string | null;
  payout_bank_name: string | null;
}

export interface ReimbursementPet {
  id: string;
  name: string;
  species: string | null;
  photo_url: string | null;
  plan_type: string | null;
}

export interface ReimbursementProviderDetail {
  id: string;
  name: string;
  category: string | null;
  phone: string | null;
  address: string | null;
  payout_method: string | null;
  payout_account_name: string | null;
  payout_account_number: string | null;
  payout_bank_name: string | null;
  is_active: boolean;
  created_at: string;
}

export type ReimbursementStatus =
  | "pending"
  | "under_review"
  | "needs_info"
  | "approved"
  | "rejected"
  | "paid";

export type PayoutTarget = "member" | "provider";

export interface AdminReimbursement {
  id: string;
  pet_id: string;
  service_type: ReimbursementServiceType;
  provider_name: string;
  service_date: string;
  claimed_amount_centavos: number;
  approved_amount_centavos: number | null;
  receipt_url: string;
  receipt_reference: string | null;
  member_notes: string | null;
  status: ReimbursementStatus;
  admin_notes: string | null;
  reviewed_at: string | null;
  paid_at: string | null;
  paid_reference: string | null;
  payout_target: PayoutTarget;
  provider_id: string | null;
  created_at: string;
  member: ReimbursementMember;
  pet: ReimbursementPet;
  provider: ReimbursementProviderDetail | null;
  events: ReimbursementEvent[];
}

export default async function AdminReimbursementsPage() {
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;

  if (!token) redirect("/admin/login");

  let claims: AdminReimbursement[] = [];
  try {
    const res = await fetch(`${BACKEND_URL}/admin/reimbursements?limit=300`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    if (res.ok) {
      claims = await res.json();
    }
  } catch {
    // surface empty state
  }

  return (
    <main className="max-w-7xl mx-auto px-6 py-10">
      <header className="mb-8 flex flex-col sm:flex-row sm:items-start sm:justify-between gap-5">
        <div>
          <p className="text-[oklch(0.72_0.115_82)] text-xs font-semibold tracking-widest uppercase mb-2">
            Member benefits
          </p>
          <h1 className="text-[oklch(0.24_0.055_258)] text-2xl font-bold tracking-tight leading-tight">
            Reimbursements
          </h1>
        </div>
        <ExportButton resource="reimbursements" />
      </header>

      <ReimbursementsTable claims={claims} />
    </main>
  );
}
