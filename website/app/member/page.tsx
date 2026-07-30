"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import Image from "next/image";
import { PlayStoreIcon } from "@/components/play-store-icon";
import { PLAY_STORE_URL } from "@/lib/app-download";

export default function MemberPage() {
  const router = useRouter();

  useEffect(() => {
    if (typeof window !== "undefined") {
      const role = localStorage.getItem("mp_role");
      if (role === "admin") {
        router.replace("/admin");
      } else {
        // Clear any stale non-admin credentials and send home
        localStorage.removeItem("mp_token");
        localStorage.removeItem("mp_role");
        localStorage.removeItem("mp_member_id");
        localStorage.removeItem("mp_user_id");
        router.replace("/");
      }
    }
  }, [router]);

  return (
    <main className="min-h-screen flex flex-col items-center justify-center bg-[#f8f7f4] px-6">
      <div className="w-full max-w-sm text-center">
        <div className="flex justify-center mb-8">
          <Link href="/">
            <Image
              src="/logo-full.png"
              alt="MetroPaws"
              width={180}
              height={60}
              className="object-contain"
              priority
            />
          </Link>
        </div>

        <div className="bg-white rounded-2xl border border-[#e8eaf2] p-8 mb-6">
          <div className="text-5xl mb-4">📱</div>
          <h1 className="font-(family-name:--font-baloo2) text-xl font-bold text-[#1a1e32] mb-2">
            Use the MetroPaws App
          </h1>
          <p className="text-sm text-[#8b8fa8] leading-relaxed">
            Member access is available exclusively through the MetroPaws mobile
            app. Download it to view your membership, manage your pets, and
            access your digital QR card.
          </p>
        </div>

        <div className="flex flex-col gap-3 mb-8">
          <a
            href={PLAY_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-3 px-4 py-3 bg-[#1a1e32] rounded-xl transition-opacity hover:opacity-90"
          >
            <PlayStoreIcon />
            <div className="text-left">
              <p className="text-[10px] text-white/60 font-medium leading-none mb-0.5">
                Get it on
              </p>
              <p className="text-sm text-white font-bold leading-none">
                Google Play
              </p>
            </div>
          </a>
          <Link
            href="/download"
            className="flex items-center justify-center px-4 py-3 rounded-xl border border-[#e8eaf2] text-sm font-semibold text-[#263258] transition-colors hover:bg-white"
          >
            Other ways to install →
          </Link>
        </div>

        <Link
          href="/"
          className="text-sm text-[#8b8fa8] hover:text-[#263258] transition-colors"
        >
          ← Back to home
        </Link>
      </div>
    </main>
  );
}
