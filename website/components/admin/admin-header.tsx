"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { signOutAction } from "@/app/admin/actions";

const NAV_LINKS = [
  { href: "/admin/dashboard", label: "Dashboard" },
  { href: "/admin/users", label: "Users" },
  { href: "/admin/clinics", label: "Clinics" },
  { href: "/admin/plans", label: "Plans" },
];

export function AdminHeader() {
  const pathname = usePathname();

  return (
    <header className="bg-[oklch(0.24_0.055_258)] border-b border-white/10">
      <div className="max-w-7xl mx-auto px-6 h-14 flex items-center justify-between">
        <div className="flex items-center gap-6">
          <div className="flex items-center gap-3">
            <Image
              src="/logo-full-white-metro.png"
              alt="MetroPaws"
              width={120}
              height={28}
              className="h-7 w-auto"
              priority
            />
            <span className="text-white/20 text-sm">·</span>
            <span className="text-white/40 text-xs font-medium tracking-wide uppercase">
              Admin
            </span>
          </div>

          <nav className="flex items-center gap-0.5">
            {NAV_LINKS.map(({ href, label }) => (
              <Link
                key={href}
                href={href}
                className={cn(
                  "px-3 py-1.5 rounded-md text-xs font-medium transition-colors duration-150",
                  pathname === href || pathname.startsWith(href + "/")
                    ? "bg-white/10 text-white"
                    : "text-white/50 hover:text-white/80 hover:bg-white/5",
                )}
              >
                {label}
              </Link>
            ))}
          </nav>
        </div>

        <div className="flex items-center gap-3">
          <form action={signOutAction}>
            <button
              type="submit"
              className="flex items-center gap-1.5 text-white/50 hover:text-white/80 text-xs font-medium transition-colors duration-150 px-3 py-1.5 rounded-md hover:bg-white/5"
            >
              Sign out
            </button>
          </form>
        </div>
      </div>
    </header>
  );
}
