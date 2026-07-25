import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ProvidersTable } from "@/components/admin/providers-table";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

export interface ReimbursementProvider {
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

export default async function AdminProvidersPage() {
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;

  if (!token) redirect("/admin/login");

  let providers: ReimbursementProvider[] = [];
  let fetchError = false;
  let unauthorized = false;
  try {
    const res = await fetch(`${BACKEND_URL}/admin/reimbursement-providers`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    if (res.status === 401) {
      unauthorized = true;
    } else if (res.ok) {
      providers = await res.json();
    } else {
      fetchError = true;
    }
  } catch {
    fetchError = true;
  }
  // redirect() throws — it must run OUTSIDE the try/catch or the catch
  // swallows it and the page shows a fetch error instead of the login page.
  if (unauthorized) redirect("/admin/login");

  return (
    <main className="max-w-7xl mx-auto px-6 py-8 md:py-10">
      <ProvidersTable providers={providers} fetchError={fetchError} />
    </main>
  );
}
