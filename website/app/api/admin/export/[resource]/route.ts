import { cookies } from "next/headers";
import { NextRequest, NextResponse } from "next/server";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

const XLSX_CONTENT_TYPE =
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

const BACKEND_EXPORT_PATHS: Record<string, string> = {
  members: "members.xlsx",
  reimbursements: "reimbursements.xlsx",
  reservations: "founding-reservations.xlsx",
};

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ resource: string }> },
) {
  const { resource } = await params;
  const backendPath = BACKEND_EXPORT_PATHS[resource];
  if (!backendPath) {
    return NextResponse.json({ error: "Unknown export." }, { status: 404 });
  }

  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;
  if (!token) {
    return NextResponse.json({ error: "Not authenticated." }, { status: 401 });
  }

  const search = request.nextUrl.search;
  const res = await fetch(`${BACKEND_URL}/admin/exports/${backendPath}${search}`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  });
  if (!res.ok || !res.body) {
    return NextResponse.json({ error: "Export failed." }, { status: res.status || 502 });
  }

  return new NextResponse(res.body, {
    headers: {
      "Content-Type": res.headers.get("Content-Type") ?? XLSX_CONTENT_TYPE,
      "Content-Disposition":
        res.headers.get("Content-Disposition") ??
        `attachment; filename="${resource}.xlsx"`,
    },
  });
}
