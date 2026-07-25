"use client";
import { useEffect } from "react";
import { usePathname } from "next/navigation";

export default function AnimationInit() {
  const pathname = usePathname();

  useEffect(() => {
    let observer: IntersectionObserver | null = null;

    const els = document.querySelectorAll<HTMLElement>(".reveal");
    if (!els.length) return;

    observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("in-view");
            observer?.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );

    els.forEach((el) => observer!.observe(el));
    return () => observer?.disconnect();
  }, [pathname]);

  return null;
}
