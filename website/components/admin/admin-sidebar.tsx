"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Users,
  Building2,
  CreditCard,
  LogOut,
  BookMarked,
  Settings,
  HelpCircle,
  Receipt,
  Megaphone,
  Wallet,
  Banknote,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { signOutAction } from "@/app/admin/actions";

const NAV_LINKS = [
  { href: "/admin/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { href: "/admin/users", label: "Users", icon: Users },
  { href: "/admin/clinics", label: "Clinics", icon: Building2 },
  { href: "/admin/plans", label: "Plans", icon: CreditCard },
  { href: "/admin/payments", label: "Payments", icon: Wallet },
  { href: "/admin/reservations", label: "Reservations", icon: BookMarked },
  { href: "/admin/reimbursements", label: "Reimbursements", icon: Receipt },
  { href: "/admin/providers", label: "Providers", icon: Banknote },
  { href: "/admin/promos", label: "Promos & Events", icon: Megaphone },
  { href: "/admin/faqs", label: "FAQs", icon: HelpCircle },
  { href: "/admin/settings", label: "Settings", icon: Settings },
];

export function AdminSidebar() {
  const pathname = usePathname();

  return (
    <aside className="w-56 shrink-0 bg-[oklch(0.24_0.055_258)] border-r border-white/10 sticky top-0 h-screen flex flex-col">
      <div className="h-14 px-5 flex items-center gap-3 border-b border-white/10">
        <Image
          src="/logo-full-white-metro.png"
          alt="MetroPaws"
          width={140}
          height={33}
          className="h-8 w-auto"
          priority
        />
        <span className="text-white/25 text-[0.625rem] font-semibold uppercase tracking-widest leading-none">
          Admin
        </span>
      </div>

      <nav className="flex-1 p-3 flex flex-col gap-0.5 overflow-y-auto">
        {NAV_LINKS.map(({ href, label, icon: Icon }) => {
          const isActive = pathname === href || pathname.startsWith(href + "/");
          return (
            <Link
              key={href}
              href={href}
              className={cn(
                "flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors duration-150",
                isActive
                  ? "bg-white/10 text-white font-semibold"
                  : "text-white/50 font-medium hover:text-white/80 hover:bg-white/5",
              )}
            >
              <Icon size={14} className="shrink-0" />
              {label}
            </Link>
          );
        })}
      </nav>

      <div className="p-3 border-t border-white/10">
        <form action={signOutAction}>
          <button
            type="submit"
            className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium text-white/50 hover:text-white/80 hover:bg-white/5 transition-colors duration-150"
          >
            <LogOut size={14} className="shrink-0" />
            Sign out
          </button>
        </form>
      </div>
    </aside>
  );
}
