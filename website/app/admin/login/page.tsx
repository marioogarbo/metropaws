"use client";

import { useActionState, useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { Loader2, Eye, EyeOff, AlertCircle } from "lucide-react";
import { loginAction } from "./actions";
import { cn } from "@/lib/utils";

const inputBase = cn(
  "w-full bg-[oklch(0.28_0.048_258)] border border-white/[0.08] hover:border-white/[0.15] text-white text-sm rounded-lg px-4 py-3",
  "placeholder:text-white/25 focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)]",
  "focus:border-transparent disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-150",
);

const bgStyle = {
  background:
    "radial-gradient(ellipse 90% 60% at 50% 35%, oklch(0.29 0.058 258), oklch(0.21 0.050 258))",
};

const INITIAL_STATE = { error: null };

export default function AdminLoginPage() {
  const [state, formAction, isPending] = useActionState(loginAction, INITIAL_STATE);
  const [showPassword, setShowPassword] = useState(false);

  return (
    <div
      className="min-h-svh flex items-center justify-center px-4 py-16"
      style={bgStyle}
    >
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex justify-center mb-8">
          <Link href="/" aria-label="Go to MetroPaws home page">
            <Image
              src="/logo-full-white-metro.png"
              alt="MetroPaws"
              width={160}
              height={40}
              className="object-contain opacity-90 hover:opacity-100 transition-opacity duration-150"
              priority
            />
          </Link>
        </div>

        {/* Card */}
        <div className="bg-white/4 border border-white/[0.07] rounded-2xl p-6 sm:p-8">
          <div className="text-center mb-6">
            <h1
              className="text-white font-bold text-2xl mb-2"
              style={{ letterSpacing: "-0.02em" }}
            >
              Admin Login
            </h1>
            <p className="text-white/40 text-sm font-medium leading-relaxed">
              Restricted access. Authorized personnel only.
            </p>
          </div>

          <form action={formAction} className="space-y-5">
            <div>
              <label
                htmlFor="email"
                className="block text-white/60 text-xs font-semibold mb-2 tracking-widest uppercase"
              >
                Email
              </label>
              <input
                id="email"
                name="email"
                type="email"
                autoComplete="email"
                autoFocus
                required
                placeholder="admin@metropaws.com"
                className={inputBase}
                disabled={isPending}
              />
            </div>

            <div>
              <label
                htmlFor="password"
                className="block text-white/60 text-xs font-semibold mb-2 tracking-widest uppercase"
              >
                Password
              </label>
              <div className="relative">
                <input
                  id="password"
                  name="password"
                  type={showPassword ? "text" : "password"}
                  autoComplete="current-password"
                  required
                  placeholder="••••••••••••"
                  className={cn(inputBase, "pr-11")}
                  disabled={isPending}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-white/30 hover:text-white/60 transition-colors duration-150 p-2"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? (
                    <EyeOff size={16} strokeWidth={1.75} />
                  ) : (
                    <Eye size={16} strokeWidth={1.75} />
                  )}
                </button>
              </div>
            </div>

            {state.error && (
              <div
                role="alert"
                aria-atomic="true"
                className="flex items-start gap-2.5 text-[oklch(0.70_0.09_15)] bg-[oklch(0.65_0.08_15)]/8 border border-[oklch(0.65_0.08_15)]/20 rounded-lg px-3 py-2.5"
              >
                <AlertCircle
                  size={15}
                  className="shrink-0 mt-0.5 opacity-75"
                  strokeWidth={1.75}
                />
                <p className="text-sm leading-relaxed wrap-break-word min-w-0">
                  {state.error}
                </p>
              </div>
            )}

            <div className="pt-2">
              <button
                type="submit"
                disabled={isPending}
                className={cn(
                  "w-full flex items-center justify-center gap-2 rounded-lg px-4 py-3",
                  "bg-[oklch(0.72_0.115_82)] text-[oklch(0.22_0.055_258)] text-sm font-semibold",
                  "hover:bg-[oklch(0.68_0.115_82)] active:bg-[oklch(0.65_0.115_82)]",
                  "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)] focus-visible:ring-offset-2 focus-visible:ring-offset-[oklch(0.24_0.055_258)]",
                  "disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-150",
                )}
              >
                {isPending ? (
                  <>
                    <Loader2 size={15} className="motion-safe:animate-spin" />
                    Signing in…
                  </>
                ) : (
                  "Sign In"
                )}
              </button>
            </div>
          </form>
        </div>

        <p className="text-center mt-6 text-sm text-white/30">
          <Link
            href="/"
            className="hover:text-white/60 transition-colors duration-150 underline underline-offset-2"
          >
            Back to MetroPaws
          </Link>
        </p>
      </div>
    </div>
  );
}
