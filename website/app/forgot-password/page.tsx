"use client";

import { useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { Mail } from "lucide-react";
import { forgotPassword } from "@/lib/api";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(e: { preventDefault: () => void }) {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      await forgotPassword(email);
      setSent(true);
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail ||
        "Failed to send reset link";
      setError(msg);
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-6 py-12 bg-(--surface) relative overflow-hidden">
      {/* Decorative dog cutout — bottom-right, fades behind content */}
      <div className="pointer-events-none select-none absolute bottom-0 right-0 w-48 opacity-20 translate-y-4">
        <Image
          src="/pet-care-dog.png"
          alt=""
          width={0}
          height={0}
          sizes="192px"
          className="object-contain w-full h-auto"
        />
      </div>

      <div className="w-full max-w-sm text-center relative z-10">
        {/* Logo */}
        <Link href="/" className="inline-block mb-10">
          <div className="w-45 mx-auto">
            <Image
              src="/logo-full.png"
              alt="MetroPaws"
              width={0}
              height={0}
              sizes="180px"
              className="object-contain w-full h-auto"
              priority
            />
          </div>
        </Link>

        {sent ? (
          <>
            {/* Success state */}
            <div className="w-16 h-16 rounded-full bg-(--gold-light) flex items-center justify-center mx-auto mb-6">
              <Mail className="w-8 h-8 text-(--gold)" />
            </div>

            <h1 className="font-(family-name:--font-baloo2) text-2xl font-extrabold text-(--text) mb-3">
              Check your inbox
            </h1>
            <p className="text-(--grey) text-base mb-8 leading-relaxed">
              We've sent a password reset link to <span className="font-semibold text-(--text)">{email}</span>. Click the link to set a new password.
            </p>

            <div className="bg-(--navy-light) rounded-2xl p-5 text-left mb-8 flex flex-col gap-3 text-sm text-(--text)">
              <p>
                <span className="font-semibold">💡 Tip:</span> The reset link expires in 1 hour.
              </p>
              <p>
                <span className="font-semibold">📁 Check:</span> If you don't see it, check your spam folder.
              </p>
            </div>

            <Link
              href="/admin/login"
              className="block w-full py-3.5 rounded-xl bg-(--navy) text-white font-bold text-base text-center hover:bg-(--navy-dark) transition-colors"
            >
              Back to Sign In
            </Link>

            <button
              onClick={() => {
                setSent(false);
                setEmail("");
              }}
              className="block w-full mt-3 py-3.5 rounded-xl border border-(--navy) text-(--navy) font-bold text-base text-center hover:bg-(--navy-light) transition-colors"
            >
              Try Another Email
            </button>
          </>
        ) : (
          <>
            {/* Request state */}
            <div className="w-16 h-16 rounded-full bg-(--gold-light) flex items-center justify-center mx-auto mb-6">
              <span className="text-3xl">🔑</span>
            </div>

            <h1 className="font-(family-name:--font-baloo2) text-2xl font-extrabold text-(--text) mb-3">
              Reset your password
            </h1>
            <p className="text-(--grey) text-base mb-8 leading-relaxed">
              Enter your email and we'll send you a link to set a new password.
            </p>

            <form onSubmit={handleSubmit} className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-semibold text-(--text) mb-2">
                  Email
                </label>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  className="w-full px-4 py-3 rounded-xl border border-(--grey-light) bg-white text-(--text) outline-none focus:border-(--navy) focus:ring-2 focus:ring-(--navy)/20 transition-all"
                />
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
                {loading ? "Sending..." : "Send Reset Link"}
              </button>
            </form>

            <p className="text-center mt-6 text-sm text-(--grey)">
              Remember your password?{" "}
              <Link href="/admin/login" className="text-(--navy) font-bold hover:underline">
                Sign In
              </Link>
            </p>
          </>
        )}
      </div>
    </main>
  );
}
