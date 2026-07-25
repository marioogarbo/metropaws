"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useState, useEffect } from "react";
import Link from "next/link";
import Image from "next/image";
import { Eye, EyeOff } from "lucide-react";
import { resetPassword } from "@/lib/api";

export default function ResetContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const token = searchParams.get("token");

  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    if (!token) {
      router.push("/forgot-password");
    }
  }, [token, router]);

  async function handleSubmit(e: { preventDefault: () => void }) {
    e.preventDefault();
    setError("");

    if (newPassword.length < 8) {
      setError("Password must be at least 8 characters");
      return;
    }

    if (newPassword !== confirmPassword) {
      setError("Passwords do not match");
      return;
    }

    setLoading(true);
    try {
      await resetPassword(token!, newPassword);
      setSuccess(true);
      // No auto-redirect: password reset is used mainly by members (via the
      // mobile app), who have no account on this website. Sending them to
      // /admin/login funnelled anyone with an existing admin session straight
      // into the admin dashboard. Show a success message instead and let them
      // return to the app; admins get an explicit staff-portal link below.
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail ||
        "Failed to reset password";
      setError(msg);
    } finally {
      setLoading(false);
    }
  }

  if (!token) {
    return null;
  }

  return (
    <div className="min-h-screen flex flex-col md:flex-row">
      {/* Form panel */}
      <div className="flex-1 flex flex-col bg-(--surface)">
        {/* Mobile brand strip — visible on phones only */}
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
              Secure your account with a new password.
            </p>
          </div>
        </div>

        <div className="flex-1 flex items-center justify-center px-6 py-8">
          <div className="w-full max-w-md">
            {/* Logo — links home */}
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

            {success ? (
              <>
                <div className="text-center">
                  <div className="w-16 h-16 rounded-full bg-(--gold-light) flex items-center justify-center mx-auto mb-6">
                    <span className="text-3xl">✓</span>
                  </div>
                  <h1 className="font-(family-name:--font-baloo2) text-3xl font-bold text-(--text) mb-2">
                    Password updated
                  </h1>
                  <p className="text-(--grey) text-base mb-8">
                    Your password has been changed successfully. Open the
                    MetroPaws app and sign in with your new password.
                  </p>
                  <p className="text-(--grey) text-sm">
                    MetroPaws staff?{" "}
                    <Link
                      href="/admin/login"
                      className="text-(--navy) font-bold hover:underline"
                    >
                      Sign in to the staff portal
                    </Link>
                  </p>
                </div>
              </>
            ) : (
              <>
                <h1 className="font-(family-name:--font-baloo2) text-3xl font-bold text-(--text) mb-2">
                  Set New Password
                </h1>
                <p className="text-(--grey) text-base mb-8">
                  Choose a strong password to secure your account.
                </p>

                <form onSubmit={handleSubmit} className="flex flex-col gap-4">
                  <div>
                    <label className="block text-sm font-semibold text-(--text) mb-1">
                      New Password
                    </label>
                    <div className="relative">
                      <input
                        type={showPassword ? "text" : "password"}
                        required
                        value={newPassword}
                        onChange={(e) => setNewPassword(e.target.value)}
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

                  <div>
                    <label className="block text-sm font-semibold text-(--text) mb-1">
                      Confirm Password
                    </label>
                    <div className="relative">
                      <input
                        type={showConfirm ? "text" : "password"}
                        required
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        placeholder="••••••••"
                        className="w-full px-4 py-3 pr-11 rounded-xl border border-(--grey-light) bg-white text-(--text) outline-none focus:border-(--navy) focus:ring-2 focus:ring-(--navy)/20 transition-all"
                      />
                      <button
                        type="button"
                        onClick={() => setShowConfirm((v) => !v)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-(--grey) hover:text-(--navy) transition-colors p-1"
                        aria-label={showConfirm ? "Hide password" : "Show password"}
                      >
                        {showConfirm ? (
                          <EyeOff className="w-4 h-4" />
                        ) : (
                          <Eye className="w-4 h-4" />
                        )}
                      </button>
                    </div>
                  </div>

                  {error && (
                    <div className="px-4 py-3 bg-(--gold-light) border border-(--gold)/40 rounded-xl text-(--text) text-sm font-medium flex items-start gap-2">
                      <span className="shrink-0 text-(--gold)">⚠</span>
                      <span>{error}</span>
                    </div>
                  )}

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full py-3.5 rounded-xl bg-(--navy) text-white font-bold text-base hover:bg-[#1A2245] transition-colors disabled:opacity-60"
                  >
                    {loading ? "Resetting..." : "Reset Password"}
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
              MetroPaws
            </span>
          </div>
          <p className="font-(family-name:--font-baloo2) text-white font-extrabold text-2xl leading-snug">
            Secure your account
            <br />
            with a new password.
          </p>
        </div>
      </div>
    </div>
  );
}
