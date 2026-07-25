"use client";
import { useState } from "react";
import Link from "next/link";
import { X } from "lucide-react";

export default function AnnouncementBanner() {
  const [visible, setVisible] = useState(true);

  function dismiss() {
    setVisible(false);
  }

  return (
    <div
      className={`grid transition-[grid-template-rows] duration-300 ease-out ${
        visible ? "grid-rows-[1fr]" : "grid-rows-[0fr]"
      }`}
    >
      <div className="overflow-hidden">
        <div className="bg-(--navy-deep) px-4 sm:px-6 py-2.5">
          <div className="max-w-5xl mx-auto flex flex-col sm:flex-row items-center justify-center sm:justify-between gap-1 sm:gap-4">

            <div className="flex flex-col sm:flex-row items-center gap-1 sm:gap-3 text-center sm:text-left">
              <span className="font-(family-name:--font-baloo2) font-bold text-[11px] tracking-widest text-(--gold) uppercase">
                Founding 50
              </span>
              <span className="hidden sm:block w-px h-3 bg-white/20 shrink-0" />
              <span className="text-white/75 text-xs sm:text-sm leading-snug">
                Locked-in pricing for our first 50 families. Spots are open now.
              </span>
            </div>

            <div className="flex items-center gap-3 shrink-0">
              <Link
                href="/#founding-50"
                className="text-(--gold) font-semibold text-xs sm:text-sm whitespace-nowrap hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--gold)/50 rounded"
              >
                Reserve yours →
              </Link>
              <button
                onClick={dismiss}
                aria-label="Dismiss announcement"
                className="w-7 h-7 flex items-center justify-center rounded-lg text-white/35 hover:text-white/75 hover:bg-white/10 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/30"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>

          </div>
        </div>
      </div>
    </div>
  );
}
