"use client";

import { useState } from "react";
import Link from "next/link";
import { submitFoundingReservation } from "@/lib/api";

const LAS_PINAS_BARANGAYS = [
  "Almanza Dos",
  "Almanza Uno",
  "CAA-B.F. International",
  "Daniel Fajardo",
  "Elias Aldana",
  "Ilaya",
  "Manuyo Dos",
  "Manuyo Uno",
  "Pamplona Dos",
  "Pamplona Tres",
  "Pamplona Uno",
  "Pilar Village",
  "Pulanglupa Dos",
  "Pulanglupa Uno",
  "Talon Cuatro",
  "Talon Dos",
  "Talon Singko",
  "Talon Tres",
  "Talon Uno",
  "Zapote",
  "Other (Metro Manila)",
];

export default function Founding50Form() {
  const [form, setForm] = useState({
    first_name: "",
    last_name: "",
    email: "",
    phone: "",
    barangay: "",
    message: "",
  });
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [submitted, setSubmitted] = useState(false);

  function set(field: string, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }));
    setError("");
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.first_name || !form.last_name || !form.email || !form.barangay) {
      setError("Please fill in all required fields.");
      return;
    }
    setSubmitting(true);
    setError("");
    try {
      await submitFoundingReservation({
        first_name: form.first_name,
        last_name: form.last_name,
        email: form.email,
        phone: form.phone || undefined,
        barangay: form.barangay,
        message: form.message || undefined,
      });
      setSubmitted(true);
    } catch (err: unknown) {
      const detail = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setError(detail || "Something went wrong. Please try again or contact us on Facebook.");
    } finally {
      setSubmitting(false);
    }
  }

  if (submitted) {
    return (
      <div className="bg-white/10 border border-white/20 rounded-2xl p-7 text-center">
        <div className="text-3xl mb-3">🐾</div>
        <h3 className="font-(family-name:--font-baloo2) font-extrabold text-white text-xl mb-2">
          You&apos;re on the list!
        </h3>
        <p className="text-white/70 text-sm leading-relaxed max-w-xs mx-auto">
          We&apos;ll review your reservation and reach out personally if you&apos;re selected as a
          Founding Member.
        </p>
        <p className="text-(--gold) text-xs font-semibold mt-4 font-(family-name:--font-baloo2)">
          Watch your inbox — and our Facebook page.
        </p>
        <div className="mt-5 pt-5 border-t border-white/15 flex flex-col gap-2.5">
          <Link
            href="/register"
            className="w-full py-2.5 rounded-xl bg-(--gold) text-(--navy) font-(family-name:--font-baloo2) font-bold text-sm text-center transition hover:bg-(--gold-dark) hover:scale-[1.01] active:scale-[0.99] inline-block focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--gold)/60"
          >
            Register Free While You Wait →
          </Link>
          <a
            href="https://www.facebook.com/people/Metropaws/61588899502470"
            target="_blank"
            rel="noopener noreferrer"
            className="text-white/45 text-[11px] hover:text-white/65 transition-colors text-center"
          >
            Follow us on Facebook for updates
          </a>
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-3" noValidate>
      <div className="grid sm:grid-cols-2 gap-3">
        <div className="flex flex-col gap-1.5">
          <label htmlFor="first_name" className="text-white/75 text-[11px] font-semibold uppercase tracking-wide">
            First name <span className="text-(--gold)">*</span>
          </label>
          <input
            id="first_name"
            value={form.first_name}
            onChange={(e) => set("first_name", e.target.value)}
            placeholder="Juan"
            className="px-3.5 py-2.5 rounded-xl bg-white/10 border border-white/20 text-white placeholder-white/30 text-sm focus:outline-none focus:border-(--gold)/60 focus:ring-2 focus:ring-(--gold)/20 transition-all"
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <label htmlFor="last_name" className="text-white/75 text-[11px] font-semibold uppercase tracking-wide">
            Last name <span className="text-(--gold)">*</span>
          </label>
          <input
            id="last_name"
            value={form.last_name}
            onChange={(e) => set("last_name", e.target.value)}
            placeholder="dela Cruz"
            className="px-3.5 py-2.5 rounded-xl bg-white/10 border border-white/20 text-white placeholder-white/30 text-sm focus:outline-none focus:border-(--gold)/60 focus:ring-2 focus:ring-(--gold)/20 transition-all"
          />
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="email" className="text-white/75 text-[11px] font-semibold uppercase tracking-wide">
          Email <span className="text-(--gold)">*</span>
        </label>
        <input
          id="email"
          type="email"
          value={form.email}
          onChange={(e) => set("email", e.target.value)}
          placeholder="juan@email.com"
          className="px-3.5 py-2.5 rounded-xl bg-white/10 border border-white/20 text-white placeholder-white/30 text-sm focus:outline-none focus:border-(--gold)/60 focus:ring-2 focus:ring-(--gold)/20 transition-all"
        />
      </div>

      <div className="grid sm:grid-cols-2 gap-3">
        <div className="flex flex-col gap-1.5">
          <label htmlFor="phone" className="text-white/75 text-[11px] font-semibold uppercase tracking-wide">
            Phone
          </label>
          <input
            id="phone"
            value={form.phone}
            onChange={(e) => set("phone", e.target.value)}
            placeholder="09xx xxx xxxx"
            className="px-3.5 py-2.5 rounded-xl bg-white/10 border border-white/20 text-white placeholder-white/30 text-sm focus:outline-none focus:border-(--gold)/60 focus:ring-2 focus:ring-(--gold)/20 transition-all"
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <label htmlFor="barangay" className="text-white/75 text-[11px] font-semibold uppercase tracking-wide">
            Barangay <span className="text-(--gold)">*</span>
          </label>
          <select
            id="barangay"
            value={form.barangay}
            onChange={(e) => set("barangay", e.target.value)}
            className="px-3.5 py-2.5 rounded-xl bg-[#1e2d50] border border-white/20 text-white text-sm focus:outline-none focus:border-(--gold)/60 focus:ring-2 focus:ring-(--gold)/20 transition-all appearance-none cursor-pointer"
          >
            <option value="" disabled className="text-white/40">
              Select barangay…
            </option>
            {LAS_PINAS_BARANGAYS.map((b) => (
              <option key={b} value={b} className="bg-[#1e2d50] text-white">
                {b}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="message" className="text-white/75 text-[11px] font-semibold uppercase tracking-wide">
          Why do you want to be a Founding Member?{" "}
          <span className="text-white/60 normal-case font-normal">(optional)</span>
        </label>
        <textarea
          id="message"
          value={form.message}
          onChange={(e) => set("message", e.target.value)}
          placeholder="Tell us about your pets and why you'd love to be part of the first 50…"
          rows={2}
          className="px-3.5 py-2.5 rounded-xl bg-white/10 border border-white/20 text-white placeholder-white/30 text-sm focus:outline-none focus:border-(--gold)/60 focus:ring-2 focus:ring-(--gold)/20 transition-all resize-none"
        />
      </div>

      {error && (
        <p className="text-amber-300 text-xs font-semibold px-1">{error}</p>
      )}

      <button
        type="submit"
        disabled={submitting}
        className="w-full py-3.5 rounded-xl bg-(--gold) text-(--navy) font-(family-name:--font-baloo2) font-bold text-sm transition hover:bg-(--gold-dark) hover:scale-[1.01] active:scale-[0.99] disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--gold)/60 mt-1"
      >
        {submitting ? "Submitting…" : "Reserve My Spot →"}
      </button>

      <p className="text-white/65 text-[11px] text-center leading-relaxed">
        Reservations are reviewed by the MetroPaws team. We&apos;ll contact you personally if selected.
      </p>
    </form>
  );
}
