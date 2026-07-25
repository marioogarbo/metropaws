"use client";

import React, { useEffect, useRef, useState } from "react";
import { Eye, EyeOff, Loader2, CheckCircle } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { cn } from "@/lib/utils";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

const namePattern = /^[\p{L}\p{M}\s'\-]+$/u;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

function sanitizePhone(raw: string): string {
  const digits = raw.replace(/\D/g, "");
  if (digits.startsWith("639") && digits.length >= 12) return digits.slice(2, 12);
  if (digits.startsWith("63") && digits.length >= 12) return digits.slice(2, 12);
  if (digits.startsWith("0")) return digits.slice(1, 11);
  return digits.slice(0, 10);
}

function isValidPhone(value: string): boolean {
  return value.length === 10 && value.startsWith("9");
}

function isValidName(value: string): boolean {
  return namePattern.test(value.trim());
}

const inputBase =
  "w-full bg-(--color-surface) border border-(--color-ink-faint) text-(--color-ink) text-sm rounded-lg px-3 py-3 placeholder:text-(--color-ink-faint) focus:outline-none focus:ring-2 focus:ring-(--color-gold) focus:border-transparent disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-150 leading-normal";

const inputError = "border-red-400 focus:ring-red-400";

// Version of the membership agreement + privacy terms shown at sign-up.
// Must match CURRENT_AGREEMENT_VERSION on the backend.
const AGREEMENT_VERSION = "2026-07";

type FieldErrors = {
  firstName: string | null;
  lastName: string | null;
  email: string | null;
  phone: string | null;
  password: string | null;
  confirmPassword: string | null;
  agreement: string | null;
  server: string | null;
};

const EMPTY_ERRORS: FieldErrors = {
  firstName: null,
  lastName: null,
  email: null,
  phone: null,
  password: null,
  confirmPassword: null,
  agreement: null,
  server: null,
};

type SubmitStatus = "idle" | "submitting" | "success";

export function RegisterForm() {
  const router = useRouter();
  const [status, setStatus] = useState<SubmitStatus>("idle");
  const [phoneValue, setPhoneValue] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [agreementAccepted, setAgreementAccepted] = useState(false);
  const [errors, setErrors] = useState<FieldErrors>(EMPTY_ERRORS);
  const passwordRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (status !== "success") return;
    const id = setTimeout(() => router.push("/"), 1800);
    return () => clearTimeout(id);
  }, [status, router]);

  function clearFieldError(field: keyof FieldErrors) {
    setErrors((prev) => ({ ...prev, [field]: null }));
  }

  function setFieldError(field: keyof FieldErrors, message: string | null) {
    setErrors((prev) => ({ ...prev, [field]: message }));
  }

  async function handleSubmit(e: React.SubmitEvent<HTMLFormElement>) {
    e.preventDefault();

    const fd = new FormData(e.currentTarget as HTMLFormElement);
    const firstName = (fd.get("first_name") as string).trim();
    const lastName = (fd.get("last_name") as string).trim();
    const email = (fd.get("email") as string).trim();
    const password = fd.get("password") as string;
    const confirmPassword = fd.get("confirm_password") as string;

    const next: FieldErrors = { ...EMPTY_ERRORS };

    if (!firstName) next.firstName = "First name is required.";
    else if (!isValidName(firstName))
      next.firstName = "Letters, spaces, hyphens, and apostrophes only.";

    if (!lastName) next.lastName = "Last name is required.";
    else if (!isValidName(lastName))
      next.lastName = "Letters, spaces, hyphens, and apostrophes only.";

    if (!email) next.email = "Email is required.";
    else if (!emailPattern.test(email)) next.email = "Enter a valid email address.";

    if (!phoneValue) next.phone = "Mobile number is required.";
    else if (!isValidPhone(phoneValue))
      next.phone = "Enter a valid Philippine mobile number (e.g. 9171234567).";

    if (!password) next.password = "Password is required.";
    else if (password.length < 8) next.password = "At least 8 characters required.";

    if (!confirmPassword) next.confirmPassword = "Please confirm your password.";
    else if (password !== confirmPassword)
      next.confirmPassword = "Passwords do not match.";

    if (!agreementAccepted)
      next.agreement =
        "Please accept the Membership Agreement and Privacy Policy to continue.";

    if (Object.values(next).some(Boolean)) {
      setErrors(next);
      requestAnimationFrame(() => {
        const firstInvalid = document.querySelector<HTMLElement>("[aria-invalid='true']");
        firstInvalid?.scrollIntoView({ behavior: "smooth", block: "center" });
        firstInvalid?.focus();
      });
      return;
    }

    setStatus("submitting");

    try {
      const res = await fetch(`${BACKEND_URL}/auth/register`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          first_name: firstName,
          last_name: lastName,
          email,
          phone: phoneValue,
          password,
          agreement_accepted: true,
          agreement_version: AGREEMENT_VERSION,
        }),
      });

      if (res.status === 400) {
        const data = await res.json().catch(() => ({}));
        if (data?.detail === "Email already registered") {
          setFieldError(
            "email",
            "This email is already registered. Try signing in instead.",
          );
        } else {
          setFieldError("server", "Something went wrong. Please try again.");
        }
        setStatus("idle");
        return;
      }

      if (res.status === 422) {
        const data = await res.json().catch(() => ({}));
        const detail = data?.detail;
        if (Array.isArray(detail)) {
          for (const err of detail) {
            const field = err?.loc?.[1];
            const msg: string = err?.msg ?? "Invalid value.";
            if (field === "email") setFieldError("email", msg);
            else if (field === "phone") setFieldError("phone", msg);
            else if (field === "password") setFieldError("password", msg);
            else if (field === "first_name") setFieldError("firstName", msg);
            else if (field === "last_name") setFieldError("lastName", msg);
          }
        } else {
          setFieldError("server", "Validation failed. Check your details and try again.");
        }
        setStatus("idle");
        return;
      }

      if (!res.ok) {
        setFieldError("server", "Something went wrong. Please try again shortly.");
        setStatus("idle");
        return;
      }

      const data = await res.json().catch(() => ({}));
      if (data?.access_token) {
        localStorage.setItem("mp_token", data.access_token);
        if (data.user_id) localStorage.setItem("mp_user_id", data.user_id);
        if (data.member_id) localStorage.setItem("mp_member_id", data.member_id);
        if (data.role) localStorage.setItem("mp_role", data.role);
      }

      setStatus("success");
    } catch {
      setFieldError("server", "Unable to connect. Check your network and try again.");
      setStatus("idle");
    }
  }

  if (status === "success") {
    return <SuccessState />;
  }

  const isSubmitting = status === "submitting";

  return (
    <>
      <div className="mb-7">
        <h1 className="mb-2 text-2xl font-bold leading-tight tracking-tight text-(--color-ink) lg:text-3xl">
          Create your account
        </h1>
        <p className="text-sm leading-relaxed text-(--color-ink-muted)">
          Sign up here, then download the MetroPaws app to add your pet and get your QR
          membership ID.
        </p>
      </div>

      <form onSubmit={handleSubmit} noValidate className="space-y-4">
        {/* Name row */}
        <div className="grid grid-cols-2 gap-3">
          <FieldLabel label="First name" required error={errors.firstName}>
            <input
              name="first_name"
              placeholder="Juan"
              autoComplete="given-name"
              required
              maxLength={50}
              disabled={isSubmitting}
              onChange={() => clearFieldError("firstName")}
              onBlur={(e) => {
                const v = e.target.value.trim();
                if (v && !isValidName(v))
                  setFieldError(
                    "firstName",
                    "Letters, spaces, hyphens, and apostrophes only.",
                  );
              }}
              aria-invalid={errors.firstName ? true : undefined}
              className={cn(inputBase, errors.firstName && inputError)}
            />
          </FieldLabel>

          <FieldLabel label="Last name" required error={errors.lastName}>
            <input
              name="last_name"
              placeholder="dela Cruz"
              autoComplete="family-name"
              required
              maxLength={50}
              disabled={isSubmitting}
              onChange={() => clearFieldError("lastName")}
              onBlur={(e) => {
                const v = e.target.value.trim();
                if (v && !isValidName(v))
                  setFieldError(
                    "lastName",
                    "Letters, spaces, hyphens, and apostrophes only.",
                  );
              }}
              aria-invalid={errors.lastName ? true : undefined}
              className={cn(inputBase, errors.lastName && inputError)}
            />
          </FieldLabel>
        </div>

        {/* Email */}
        <FieldLabel label="Email" required error={errors.email}>
          <input
            name="email"
            type="email"
            placeholder="you@email.com"
            autoComplete="email"
            required
            maxLength={254}
            disabled={isSubmitting}
            onChange={() => clearFieldError("email")}
            onBlur={(e) => {
              const v = e.target.value.trim();
              if (v && !emailPattern.test(v))
                setFieldError("email", "Enter a valid email address.");
            }}
            aria-invalid={errors.email ? true : undefined}
            className={cn(inputBase, errors.email && inputError)}
          />
        </FieldLabel>

        {/* Phone */}
        <FieldLabel label="Mobile number" required error={errors.phone}>
          <div className="relative">
            <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 select-none text-sm text-(--color-ink-muted)">
              +63
            </span>
            <input
              name="phone"
              type="tel"
              inputMode="numeric"
              placeholder="9171234567"
              autoComplete="tel"
              required
              maxLength={10}
              value={phoneValue}
              onChange={(e) => {
                setPhoneValue(sanitizePhone(e.target.value));
                clearFieldError("phone");
              }}
              onBlur={() => {
                if (phoneValue && !isValidPhone(phoneValue))
                  setFieldError(
                    "phone",
                    "Enter a valid Philippine mobile number (e.g. 9171234567).",
                  );
              }}
              disabled={isSubmitting}
              aria-invalid={errors.phone ? true : undefined}
              className={cn(inputBase, "pl-11", errors.phone && inputError)}
            />
          </div>
        </FieldLabel>

        {/* Password */}
        <FieldLabel label="Password" required error={errors.password}>
          <div className="relative">
            <input
              ref={passwordRef}
              name="password"
              type={showPassword ? "text" : "password"}
              placeholder="At least 8 characters"
              autoComplete="new-password"
              required
              disabled={isSubmitting}
              onChange={() => clearFieldError("password")}
              onBlur={(e) => {
                if (e.target.value && e.target.value.length < 8)
                  setFieldError("password", "At least 8 characters required.");
              }}
              aria-invalid={errors.password ? true : undefined}
              className={cn(inputBase, "pr-10", errors.password && inputError)}
            />
            <PasswordToggle
              visible={showPassword}
              fieldLabel="password"
              onToggle={() => setShowPassword((v) => !v)}
            />
          </div>
        </FieldLabel>

        {/* Confirm password */}
        <FieldLabel label="Confirm password" required error={errors.confirmPassword}>
          <div className="relative">
            <input
              name="confirm_password"
              type={showConfirm ? "text" : "password"}
              placeholder="Repeat your password"
              autoComplete="new-password"
              required
              disabled={isSubmitting}
              onChange={() => clearFieldError("confirmPassword")}
              onBlur={(e) => {
                if (
                  e.target.value &&
                  passwordRef.current &&
                  e.target.value !== passwordRef.current.value
                )
                  setFieldError("confirmPassword", "Passwords do not match.");
              }}
              aria-invalid={errors.confirmPassword ? true : undefined}
              className={cn(inputBase, "pr-10", errors.confirmPassword && inputError)}
            />
            <PasswordToggle
              visible={showConfirm}
              fieldLabel="confirm password"
              onToggle={() => setShowConfirm((v) => !v)}
            />
          </div>
        </FieldLabel>

        {/* Digital Agreement acceptance — required for members */}
        <div className="pt-1">
          <label className="flex cursor-pointer items-start gap-3">
            <input
              type="checkbox"
              name="agreement"
              checked={agreementAccepted}
              disabled={isSubmitting}
              onChange={(e) => {
                setAgreementAccepted(e.target.checked);
                if (e.target.checked) clearFieldError("agreement");
              }}
              aria-invalid={errors.agreement ? true : undefined}
              className="mt-0.5 h-4 w-4 shrink-0 cursor-pointer accent-(--color-gold)"
            />
            <span className="text-sm leading-relaxed text-(--color-ink-muted)">
              I have read and accept the{" "}
              <Link
                href="/terms-of-service"
                className="font-medium text-(--color-navy) underline underline-offset-2 transition-colors hover:text-(--color-gold)"
              >
                Membership Agreement
              </Link>{" "}
              and{" "}
              <Link
                href="/privacy-policy"
                className="font-medium text-(--color-navy) underline underline-offset-2 transition-colors hover:text-(--color-gold)"
              >
                Privacy Policy
              </Link>
              .
            </span>
          </label>
          {errors.agreement && (
            <p role="alert" className="mt-1.5 text-sm text-red-600">
              {errors.agreement}
            </p>
          )}
        </div>

        {errors.server && (
          <p role="alert" className="text-sm text-red-600">
            {errors.server}
          </p>
        )}

        <button
          type="submit"
          disabled={isSubmitting}
          className="mt-2 flex w-full items-center justify-center gap-2 rounded-lg bg-(--color-gold) px-6 py-4 text-sm font-semibold text-(--color-navy) transition-all duration-200 ease-out hover:brightness-105 motion-safe:hover:-translate-y-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-offset-2 focus-visible:ring-offset-(--color-cream) disabled:cursor-not-allowed disabled:opacity-60"
        >
          {isSubmitting && (
            <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />
          )}
          {isSubmitting ? "Creating account..." : "Create account"}
        </button>

        <p className="text-center text-sm text-(--color-ink-muted)">
          Already have an account? Sign in from the MetroPaws app to view your
          pet&apos;s QR membership ID.
        </p>
      </form>
    </>
  );
}

function SuccessState() {
  return (
    <div className="mp-rise text-center">
      <div className="mx-auto mb-6 flex h-14 w-14 items-center justify-center rounded-full bg-(--color-gold)/10">
        <CheckCircle
          className="h-7 w-7 text-(--color-gold)"
          strokeWidth={1.5}
          aria-hidden="true"
        />
      </div>
      <h2 className="mb-2 text-2xl font-bold tracking-tight text-(--color-ink)">
        Account created.
      </h2>
      <p className="text-sm leading-relaxed text-(--color-ink-muted)">
        Download the MetroPaws app to add your pet and get your QR membership ID.
      </p>
      <p className="mt-4 text-sm text-(--color-ink-faint)">Redirecting you now...</p>
    </div>
  );
}

interface PasswordToggleProps {
  visible: boolean;
  fieldLabel: string;
  onToggle: () => void;
}

function PasswordToggle({ visible, fieldLabel, onToggle }: PasswordToggleProps) {
  return (
    <button
      type="button"
      onClick={onToggle}
      aria-label={visible ? `Hide ${fieldLabel}` : `Show ${fieldLabel}`}
      className="absolute right-0 top-0 flex h-full w-11 items-center justify-center text-(--color-ink-faint) transition-colors hover:text-(--color-ink-muted) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-inset"
    >
      {visible ? (
        <EyeOff className="h-4 w-4" aria-hidden="true" />
      ) : (
        <Eye className="h-4 w-4" aria-hidden="true" />
      )}
    </button>
  );
}

interface FieldLabelProps {
  label: string;
  required?: boolean;
  error?: string | null;
  children: React.ReactNode;
}

function FieldLabel({ label, required, error, children }: FieldLabelProps) {
  return (
    <label className="flex cursor-pointer flex-col gap-1.5">
      <span className="text-sm font-semibold uppercase tracking-wider text-(--color-ink-muted)">
        {label}
        {required && (
          <span className="ml-0.5 text-(--color-gold)" aria-hidden="true">
            *
          </span>
        )}
      </span>
      {children}
      {error && (
        <span role="alert" className="-mt-0.5 text-sm text-red-600">
          {error}
        </span>
      )}
    </label>
  );
}
