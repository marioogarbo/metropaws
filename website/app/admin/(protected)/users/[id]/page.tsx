import { cookies } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { MemberDetail } from "@/components/admin/member-detail";
import type { Session } from "@/components/admin/member-detail";
import type { Member } from "@/app/admin/(protected)/users/page";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

interface ServiceLogRaw {
  id: string;
  service_type: { id: string; name: string; description: string | null; icon: string };
  notes: string | null;
  logged_at: string;
}

export default async function MemberDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;

  if (!token) redirect("/admin/login");

  let member: Member | null = null;
  let sessions: Session[] = [];

  try {
    const [membersRes, logsRes] = await Promise.all([
      fetch(`${BACKEND_URL}/admin/members?limit=200`, {
        headers: { Authorization: `Bearer ${token}` },
        cache: "no-store",
      }),
      fetch(`${BACKEND_URL}/admin/logs?member_id=${encodeURIComponent(id)}&limit=100`, {
        headers: { Authorization: `Bearer ${token}` },
        cache: "no-store",
      }),
    ]);

    if (membersRes.ok) {
      const members: Member[] = await membersRes.json();
      member = members.find((m) => m.id === id) ?? null;
    }

    if (logsRes.ok && member) {
      const logs: ServiceLogRaw[] = await logsRes.json();
      sessions = logs.map((log) => ({
        id: log.id,
        service_type: log.service_type.name,
        clinic_name: null,
        scheduled_at: null,
        completed_at: log.logged_at,
        status: "completed",
        notes: log.notes ?? null,
      }));
    }
  } catch {
    // surface empty state; notFound() handles missing member below
  }

  if (!member) notFound();

  return <MemberDetail member={member} sessions={sessions} />;
}
