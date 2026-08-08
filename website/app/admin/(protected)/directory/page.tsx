import { Suspense } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { DirectoryTable } from "@/components/admin/directory-table";
import type { DirectoryProvider } from "@/types/directory";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

async function DirectoryContent({ token }: { token: string }) {
  let providers: DirectoryProvider[] = [];
  let fetchError = false;
  let unauthorized = false;

  try {
    const res = await fetch(`${BACKEND_URL}/admin/directory`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    if (res.ok) {
      providers = await res.json();
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

  return <DirectoryTable providers={providers} fetchError={fetchError} />;
}

function DirectorySkeleton() {
  return (
    <div className="animate-pulse">
      <div className="mb-8 flex items-end justify-between gap-4">
        <div className="space-y-2">
          <div className="h-3 w-32 rounded bg-[oklch(0.88_0.010_258)]" />
          <div className="h-7 w-48 rounded bg-[oklch(0.88_0.010_258)]" />
        </div>
        <div className="h-9 w-28 rounded bg-[oklch(0.88_0.010_258)]" />
      </div>
      <div className="space-y-2">
        {[0, 1, 2, 3, 4].map((row) => (
          <div
            key={row}
            className="flex items-center justify-between rounded-xl border border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] px-5 py-4"
          >
            <div className="mr-10 flex-1 space-y-1.5">
              <div className="h-3.5 w-2/5 rounded bg-[oklch(0.88_0.010_258)]" />
              <div className="h-2.5 w-1/4 rounded bg-[oklch(0.92_0.010_258)]" />
            </div>
            <div className="h-6 w-16 rounded bg-[oklch(0.88_0.010_258)]" />
          </div>
        ))}
      </div>
    </div>
  );
}

export default async function AdminDirectoryPage() {
  const cookieStore = await cookies();
  const token = cookieStore.get("admin_token")?.value;

  if (!token) redirect("/admin/login");

  return (
    <main className="max-w-6xl mx-auto px-6 py-8 md:py-10">
      <Suspense fallback={<DirectorySkeleton />}>
        <DirectoryContent token={token} />
      </Suspense>
    </main>
  );
}
