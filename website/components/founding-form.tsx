"use client";

import { useState } from "react";
import { Loader2, CheckCircle } from "lucide-react";
import { cn } from "@/lib/utils";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

const LAS_PINAS_BARANGAYS = [
  "Almanza Dos",
  "Almanza Uno",
  "BF Homes",
  "Daniel Fajardo",
  "Elias Aldana",
  "Gatchalian",
  "Ilaya",
  "Lingunan",
  "Manuyo Dos",
  "Manuyo Uno",
  "Pamplona Dos",
  "Pamplona Tres",
  "Pamplona Uno",
  "Pilar",
  "Pulang Lupa Dos",
  "Pulang Lupa Uno",
  "Talon Dos",
  "Talon Kuatro",
  "Talon Singko",
  "Talon Tres",
  "Talon Uno",
  "Zapote",
];

const inputBase =
  "w-full bg-(--color-navy-mid) border border-white/10 text-white text-sm rounded-lg px-3 py-3 placeholder:text-white/30 focus:outline-none focus:ring-2 focus:ring-(--color-gold) focus:border-transparent disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-150 leading-normal";

type SubmitStatus = "idle" | "submitting" | "success";

type FormErrors = {
  firstName: string | null;
  lastName: string | null;
  email: string | null;
  phone: string | null;
  barangay: string | null;
  server: string | null;
};

const EMPTY_ERRORS: FormErrors = {
  firstName: null,
  lastName: null,
  email: null,
  phone: null,
  barangay: null,
  server: null,
};

const MESSAGE_MAX = 500;

const namePattern = /^[\p{L}\p{M}\s'\-]+$/u;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

function sanitizePhone(raw: string): string {
  const digits = raw.replace(/\D/g, "");
  const withoutLeadingZero = digits.replace(/^0/, "");
  return withoutLeadingZero.slice(0, 10);
}

function isValidName(value: string): boolean {
  return namePattern.test(value.trim());
}

function messageCounterClass(length: number): string {
  if (length >= 480) return "text-red-400";
  if (length >= 400) return "text-(--color-gold-muted)";
  return "text-white/25";
}

export function FoundingForm() {
  const [status, setStatus] = useState<SubmitStatus>("idle");
  const [phoneValue, setPhoneValue] = useState("");
  const [errors, setErrors] = useState<FormErrors>(EMPTY_ERRORS);

  function clearFieldError(field: keyof FormErrors) {
    setErrors((prev) => ({ ...prev, [field]: null }));
  }

  function setFieldError(field: keyof FormErrors, error: string | null) {
    setErrors((prev) => ({ ...prev, [field]: error }));
  }

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const fd = new FormData(event.currentTarget);
    const firstName = (fd.get("first_name") as string).trim();
    const lastName = (fd.get("last_name") as string).trim();
    const email = (fd.get("email") as string).trim();
    const barangay = fd.get("barangay") as string;

    const nextErrors: FormErrors = { ...EMPTY_ERRORS };

    if (!firstName) {
      nextErrors.firstName = "First name is required.";
    } else if (!isValidName(firstName)) {
      nextErrors.firstName = "Only letters, spaces, hyphens, and apostrophes allowed.";
    }

    if (!lastName) {
      nextErrors.lastName = "Last name is required.";
    } else if (!isValidName(lastName)) {
      nextErrors.lastName = "Only letters, spaces, hyphens, and apostrophes allowed.";
    }

    if (!email) {
      nextErrors.email = "Email is required.";
    } else if (!emailPattern.test(email)) {
      nextErrors.email = "Enter a valid email address.";
    }

    if (!phoneValue) {
      nextErrors.phone = "Phone number is required.";
    } else if (phoneValue.length !== 10) {
      nextErrors.phone = "Enter a valid 10-digit Philippine mobile number.";
    }

    if (!barangay) {
      nextErrors.barangay = "Please select your barangay.";
    }

    const hasError = Object.values(nextErrors).some(Boolean);
    if (hasError) {
      setErrors(nextErrors);
      return;
    }

    setStatus("submitting");

    const message = (fd.get("message") as string).trim();
    const payload: Record<string, string> = {
      first_name: firstName,
      last_name: lastName,
      email,
      barangay,
      phone: phoneValue,
    };
    if (message) payload.message = message;

    try {
      const res = await fetch(`${BACKEND_URL}/founding-reservations`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (res.status === 409) {
        setErrors((prev) => ({
          ...prev,
          email: "This email has already been submitted.",
        }));
        setStatus("idle");
        return;
      }

      if (!res.ok) {
        setErrors((prev) => ({
          ...prev,
          server: "Something went wrong. Please try again shortly.",
        }));
        setStatus("idle");
        return;
      }

      setStatus("success");
    } catch {
      setErrors((prev) => ({
        ...prev,
        server: "Unable to connect. Check your network and try again.",
      }));
      setStatus("idle");
    }
  }

  if (status === "success") {
    return <SuccessState />;
  }

  const isSubmitting = status === "submitting";

  return (
    <FormContent
      isSubmitting={isSubmitting}
      phoneValue={phoneValue}
      errors={errors}
      onPhoneChange={(v) => {
        setPhoneValue(sanitizePhone(v));
        clearFieldError("phone");
      }}
      onFieldClear={clearFieldError}
      onFieldError={setFieldError}
      onSubmit={handleSubmit}
    />
  );
}

function SuccessState() {
  return (
    <div className="mp-rise">
      <div className="flex items-center justify-center w-14 h-14 rounded-full bg-(--color-gold)/15 mb-8">
        <CheckCircle
          className="w-7 h-7 text-(--color-gold)"
          strokeWidth={1.5}
          aria-hidden="true"
        />
      </div>
      <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold) mb-3">
        Reservation received
      </p>
      <h2 className="text-3xl lg:text-4xl font-bold text-white leading-tight tracking-tight mb-4">
        You&apos;re in the queue.
      </h2>
      <p className="text-sm text-white/60 leading-relaxed max-w-[52ch]">
        Our team personally reviews every reservation and contacts each selected family
        directly. We&apos;ll be in touch.
      </p>
    </div>
  );
}

interface FormContentProps {
  isSubmitting: boolean;
  phoneValue: string;
  errors: FormErrors;
  onPhoneChange: (v: string) => void;
  onFieldClear: (field: keyof FormErrors) => void;
  onFieldError: (field: keyof FormErrors, error: string | null) => void;
  onSubmit: (event: React.FormEvent<HTMLFormElement>) => void;
}

function FormContent({
  isSubmitting,
  phoneValue,
  errors,
  onPhoneChange,
  onFieldClear,
  onFieldError,
  onSubmit,
}: FormContentProps) {
  const [messageLength, setMessageLength] = useState(0);

  return (
    <>
      <div className="mb-10">
        <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold) mb-4">
          By invitation · Limited spots
        </p>
        <h2 className="text-4xl lg:text-5xl font-bold leading-tight tracking-tight">
          <span className="text-white">Founding </span>
          <span className="text-(--color-gold)">50</span>
        </h2>
        <div className="w-10 h-px bg-(--color-gold)/40 my-5" aria-hidden="true" />
        <p className="text-sm text-white/70 leading-relaxed max-w-[52ch]">
          We&apos;re personally selecting our first 50 founding families, one community at
          a time: locked-in pricing, first access to every feature we ship, and an
          exclusive badge on their MetroPaws profile. Submit below and we&apos;ll be in
          touch if you&apos;re selected.
        </p>
      </div>

      <form onSubmit={onSubmit} noValidate className="space-y-4">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <FieldLabel label="First Name" required error={errors.firstName}>
            <input
              name="first_name"
              placeholder="Juan"
              required
              autoComplete="given-name"
              maxLength={50}
              disabled={isSubmitting}
              onChange={() => onFieldClear("firstName")}
              onBlur={(e) => {
                const v = e.target.value.trim();
                if (v && !isValidName(v))
                  onFieldError(
                    "firstName",
                    "Only letters, spaces, hyphens, and apostrophes allowed.",
                  );
              }}
              aria-invalid={errors.firstName ? true : undefined}
              className={cn(
                inputBase,
                errors.firstName && "border-red-500/50 focus:ring-red-500",
              )}
            />
          </FieldLabel>
          <FieldLabel label="Last Name" required error={errors.lastName}>
            <input
              name="last_name"
              placeholder="dela Cruz"
              required
              autoComplete="family-name"
              maxLength={50}
              disabled={isSubmitting}
              onChange={() => onFieldClear("lastName")}
              onBlur={(e) => {
                const v = e.target.value.trim();
                if (v && !isValidName(v))
                  onFieldError(
                    "lastName",
                    "Only letters, spaces, hyphens, and apostrophes allowed.",
                  );
              }}
              aria-invalid={errors.lastName ? true : undefined}
              className={cn(
                inputBase,
                errors.lastName && "border-red-500/50 focus:ring-red-500",
              )}
            />
          </FieldLabel>
        </div>

        <FieldLabel label="Email" required error={errors.email}>
          <input
            name="email"
            type="email"
            placeholder="juan@email.com"
            required
            autoComplete="email"
            maxLength={254}
            disabled={isSubmitting}
            onChange={() => onFieldClear("email")}
            onBlur={(e) => {
              const v = e.target.value.trim();
              if (v && !emailPattern.test(v))
                onFieldError("email", "Enter a valid email address.");
            }}
            aria-invalid={errors.email ? true : undefined}
            className={cn(
              inputBase,
              errors.email && "border-red-500/50 focus:ring-red-500",
            )}
          />
        </FieldLabel>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <FieldLabel label="Phone" required error={errors.phone}>
            <input
              name="phone"
              type="tel"
              inputMode="numeric"
              placeholder="9xx xxx xxxx"
              autoComplete="tel"
              required
              maxLength={10}
              value={phoneValue}
              onChange={(e) => onPhoneChange(e.target.value)}
              onBlur={() => {
                if (phoneValue && phoneValue.length !== 10)
                  onFieldError(
                    "phone",
                    "Enter a valid 10-digit Philippine mobile number.",
                  );
              }}
              disabled={isSubmitting}
              aria-invalid={errors.phone ? true : undefined}
              className={cn(
                inputBase,
                errors.phone && "border-red-500/50 focus:ring-red-500",
              )}
            />
          </FieldLabel>
          <FieldLabel label="Barangay" required error={errors.barangay}>
            <div className="relative">
              <select
                name="barangay"
                required
                defaultValue=""
                disabled={isSubmitting}
                onChange={() => onFieldClear("barangay")}
                aria-invalid={errors.barangay ? true : undefined}
                className={cn(
                  inputBase,
                  "appearance-none pr-9 cursor-pointer",
                  errors.barangay && "border-red-500/50 focus:ring-red-500",
                )}
              >
                <option value="" disabled>
                  Select barangay...
                </option>
                {LAS_PINAS_BARANGAYS.map((brgy) => (
                  <option key={brgy} value={brgy}>
                    {brgy}
                  </option>
                ))}
              </select>
              <div
                className="pointer-events-none absolute inset-y-0 right-3 flex items-center"
                aria-hidden="true"
              >
                <svg width="12" height="7" viewBox="0 0 12 7" fill="none">
                  <path
                    d="M1 1L6 6L11 1"
                    stroke="currentColor"
                    strokeOpacity="0.35"
                    strokeWidth="1.5"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </div>
            </div>
          </FieldLabel>
        </div>

        <FieldLabel label="Why do you want to be a Founding Member?" hint="optional">
          <textarea
            name="message"
            placeholder="Tell us about your pets and why you'd love to be part of the first 50..."
            rows={3}
            maxLength={MESSAGE_MAX}
            disabled={isSubmitting}
            onChange={(e) => setMessageLength(e.target.value.length)}
            className={cn(inputBase, "resize-none")}
          />
          <span
            className={cn(
              "text-xs tabular-nums text-right transition-colors duration-200",
              messageCounterClass(messageLength),
            )}
            aria-live="polite"
            aria-atomic="true"
          >
            {messageLength} / {MESSAGE_MAX}
          </span>
        </FieldLabel>

        {errors.server && (
          <p role="alert" className="text-xs text-red-400">
            {errors.server}
          </p>
        )}

        <button
          type="submit"
          disabled={isSubmitting}
          className="w-full flex items-center justify-center gap-2 bg-(--color-gold) text-(--color-navy) text-sm font-semibold rounded-lg px-6 py-4 mt-2 transition-all duration-200 ease-out hover:brightness-105 motion-safe:hover:-translate-y-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-offset-2 focus-visible:ring-offset-(--color-navy) disabled:opacity-60 disabled:cursor-not-allowed"
        >
          {isSubmitting && (
            <Loader2 className="w-4 h-4 animate-spin" aria-hidden="true" />
          )}
          {isSubmitting ? "Submitting..." : "Reserve My Spot →"}
        </button>

        <p className="text-xs text-white/35 text-center leading-relaxed">
          Reservations are reviewed by the MetroPaws team. We&apos;ll contact you
          personally if selected.
        </p>
      </form>
    </>
  );
}

interface FieldLabelProps {
  label: string;
  required?: boolean;
  hint?: string;
  error?: string | null;
  children: React.ReactNode;
}

function FieldLabel({ label, required, hint, error, children }: FieldLabelProps) {
  return (
    <label className="flex flex-col gap-1.5 cursor-pointer">
      <span className="text-xs font-semibold uppercase tracking-wider text-white/50">
        {label}
        {required && (
          <span className="text-(--color-gold) ml-0.5" aria-hidden="true">
            *
          </span>
        )}
        {hint && (
          <span className="ml-1.5 normal-case tracking-normal font-normal text-white/30">
            ({hint})
          </span>
        )}
      </span>
      {children}
      {error && (
        <span role="alert" className="text-xs text-red-400 -mt-0.5">
          {error}
        </span>
      )}
    </label>
  );
}
