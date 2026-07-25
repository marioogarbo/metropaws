"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import Image from "next/image";
import { Eye, EyeOff } from "lucide-react";
import { login } from "@/lib/api";

export default function LoginContent() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: { preventDefault: () => void }) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await login(email, password);
      if (res.role === "admin") {
        router.push("/admin");
      } else {
        // Member or clinic accounts belong in the mobile app
        setError(
          "This portal is for MetroPaws staff only. Members should use the mobile app to access their membership."
        );
        // Clear stored credentials since they won't be used here
        localStorage.removeItem("mp_token");
        localStorage.removeItem("mp_role");
        localStorage.removeItem("mp_member_id");
        localStorage.removeItem("mp_user_id");
      }
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { detail?: string } } })?.response?.data
          ?.detail || "Login failed. Check your credentials and try again.";
      setError(msg);
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen flex flex-col md:flex-row">
      {/* Form panel */}
      <div className="flex-1 flex flex-col bg-(--surface)">
        {/* Mobile brand strip */}
        <div className="md:hidden relative w-full h-36 overflow-hidden shrink-0">
          <Image
            src="/pet-care-login.jpg"
            alt=""
            fill
            sizes="(max-width: 768px) 100vw, 0px"
            className="object-cover object-center"
            priority
          />
          <div className="absolute inset-0 bg-(--navy)/55" />
          <div className="absolute bottom-4 left-5 right-5">
            <p className="font-(family-name:--font-baloo2) text-white font-extrabold text-lg leading-snug">
              MetroPaws Staff Portal
            </p>
          </div>
        </div>

        <div className="flex-1 flex items-center justify-center px-6 py-8">
          <div className="w-full max-w-md">
            <div className="mb-8">
              <Link href="/">
                <div className="w-40 sm:w-55">
                  <Image
                    src="/logo-full.png"
                    alt="MetroPaws"
                    width={0}
                    height={0}
                    sizes="(max-width: 640px) 160px, 220px"
                    className="object-contain w-full h-auto"
                    priority
                  />
                </div>
              </Link>
            </div>

            <h1 className="font-(family-name:--font-baloo2) text-3xl font-bold text-(--text) mb-2">
              Staff Sign In
            </h1>
            <p className="text-(--grey) text-base mb-8">
              Access the admin dashboard to manage members, plans, and services.
            </p>

            <form onSubmit={handleSubmit} className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-semibold text-(--text) mb-1">
                  Email
                </label>
                <input
                  type="email"
                  required
                  autoComplete="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  className="w-full px-4 py-3 rounded-xl border border-(--grey-light) bg-white text-(--text) outline-none focus:border-(--navy) focus:ring-2 focus:ring-(--navy)/20 transition-all"
                />
              </div>

              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="block text-sm font-semibold text-(--text)">
                    Password
                  </label>
                  <Link
                    href="/forgot-password"
                    className="text-xs text-(--grey) hover:text-(--navy) transition-colors py-1.5 -my-1.5 inline-block"
                  >
                    Forgot password?
                  </Link>
                </div>
                <div className="relative">
                  <input
                    type={showPassword ? "text" : "password"}
                    required
                    autoComplete="current-password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="••••••••"
                    className="w-full px-4 py-3 pr-11 rounded-xl border border-(--grey-light) bg-white text-(--text) outline-none focus:border-(--navy) focus:ring-2 focus:ring-(--navy)/20 transition-all"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword((v) => !v)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-(--grey) hover:text-(--navy) transition-colors p-1"
                    aria-label={showPassword ? "Hide password" : "Show password"}
                  >
                    {showPassword ? (
                      <EyeOff className="w-4 h-4" />
                    ) : (
                      <Eye className="w-4 h-4" />
                    )}
                  </button>
                </div>
              </div>

              {error && (
                <div className="px-4 py-3 bg-(--error-light) border border-(--error)/40 rounded-xl text-(--text) text-sm font-medium flex items-start gap-2">
                  <span className="shrink-0 text-(--error)">⚠</span>
                  <span>{error}</span>
                </div>
              )}

              <button
                type="submit"
                disabled={loading}
                className="w-full py-3.5 rounded-xl bg-(--navy) text-white font-bold text-base hover:bg-(--navy-dark) transition-colors disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
              >
                {loading ? "Signing in…" : "Sign In"}
              </button>
            </form>

            <div className="mt-8 p-4 bg-(--navy)/5 rounded-xl border border-(--navy)/10">
              <p className="text-sm text-(--grey) text-center">
                Are you a MetroPaws member?{" "}
                <Link
                  href="/register"
                  className="text-(--navy) font-bold hover:underline"
                >
                  Get the app →
                </Link>
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Image panel — desktop only */}
      <div className="hidden md:block relative md:w-2/5 lg:w-1/2">
        <Image
          src="/pet-care-login.jpg"
          alt="A happy dog at a MetroPaws partner clinic"
          fill
          sizes="(max-width: 768px) 0px, (max-width: 1024px) 40vw, 50vw"
          className="object-cover object-center"
          priority
        />
        <div className="absolute inset-0 bg-(--navy)/40" />
        <div className="absolute bottom-12 left-10 right-10">
          <div className="flex items-center gap-2 mb-3">
            <span className="w-1.5 h-1.5 rounded-full bg-(--gold)" />
            <span className="text-(--gold) font-(family-name:--font-baloo2) font-bold text-xs tracking-widest uppercase">
              MetroPaws Staff Portal
            </span>
          </div>
          <p className="font-(family-name:--font-baloo2) text-white font-extrabold text-2xl leading-snug">
            Scan. Verify. Deploy.
          </p>
          <p className="text-white/60 text-sm mt-2">
            Fast, reliable clinic tools — built for busy front desks.
          </p>
        </div>
      </div>
    </main>
  );
}
