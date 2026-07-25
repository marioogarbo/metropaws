import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ClinicsTable } from "@/components/admin/clinics-table";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

export interface ClinicPartner {
  id: string;
  clinic_name: string;
  phone: string | null;
  address: string | null;
  user_id: string;
  email: string | null;
  created_at: string;
}

export default async function AdminClinicsPage() {
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;

  if (!token) redirect("/admin/login");

  let clinics: ClinicPartner[] = [];
  let fetchError = false;
  let unauthorized = false;
  try {
    const res = await fetch(`${BACKEND_URL}/admin/clinic-partners`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    if (res.status === 401) {
      unauthorized = true;
    } else if (res.ok) {
      clinics = await res.json();
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
      <ClinicsTable clinics={clinics} fetchError={fetchError} />
    </main>
  );
}
