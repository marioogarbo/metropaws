import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { UsersTable } from "@/components/admin/users-table";
import { ExportButton } from "@/components/admin/export-button";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

export interface PetService {
  id: string;
  service_type: { id: string; name: string; description: string | null; icon: string };
  total_sessions: number;
  used_sessions: number;
  remaining_sessions: number;
  expires_at: string | null;
}

export interface Pet {
  id: string;
  name: string;
  species: string | null;
  breed: string | null;
  birth_month: number | null;
  birth_year: number | null;
  birth_day: number | null;
  weight_kg: number | null;
  sex: string | null;
  photo_url: string | null;
  notes: string | null;
  plan_type: string | null;
  pet_services: PetService[];
}

export interface Member {
  id: string;
  email: string | null;
  first_name: string;
  last_name: string;
  phone: string | null;
  address: string | null;
  is_founding: boolean;
  joined_at: string;
  pets: Pet[];
}

export default async function AdminUsersPage() {
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;

  if (!token) redirect("/admin/login");

  let members: Member[] = [];
  try {
    const res = await fetch(`${BACKEND_URL}/admin/members?limit=200`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    if (res.ok) {
      members = await res.json();
    }
  } catch {
    // surface empty state
  }

  return (
    <main className="max-w-7xl mx-auto px-6 py-10">
      <div className="mb-8 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-5">
        <div>
          <p className="text-[oklch(0.72_0.115_82)] text-xs font-semibold tracking-widest uppercase mb-1.5">
            Users
          </p>
          <div className="flex items-baseline gap-3">
            <h1 className="text-[oklch(0.24_0.055_258)] text-2xl font-semibold tracking-tight">
              Members
            </h1>
            <span className="text-[oklch(0.48_0.02_258)] text-sm font-normal">
              {members.length} registered
            </span>
          </div>
        </div>
        <ExportButton resource="members" />
      </div>

      <UsersTable members={members} />
    </main>
  );
}
