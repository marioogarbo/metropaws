import { cookies } from "next/headers";
import { NextRequest, NextResponse } from "next/server";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

// Streams a paid payment's branded PDF receipt from the backend so an admin can
// view it inline (default) or download it (?download=true). The admin JWT lives
// in an httpOnly cookie the browser can't send cross-origin to the backend, so
// this same-origin route reads it and forwards it as a Bearer token.
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;

  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;
  if (!token) {
    return NextResponse.json({ error: "Not authenticated." }, { status: 401 });
  }

  const download = request.nextUrl.searchParams.get("download") === "true";
  const res = await fetch(
    `${BACKEND_URL}/admin/payments/${id}/invoice${download ? "?download=true" : ""}`,
    { headers: { Authorization: `Bearer ${token}` }, cache: "no-store" },
  );

  if (!res.ok || !res.body) {
    const body = await res.json().catch(() => null);
    return NextResponse.json(
      { error: (body as { detail?: string } | null)?.detail ?? "Couldn't load the receipt." },
      { status: res.status || 502 },
    );
  }

  return new NextResponse(res.body, {
    headers: {
      "Content-Type": res.headers.get("Content-Type") ?? "application/pdf",
      "Content-Disposition":
        res.headers.get("Content-Disposition") ??
        `${download ? "attachment" : "inline"}; filename="MetroPaws-Receipt-${id}.pdf"`,
    },
  });
}
