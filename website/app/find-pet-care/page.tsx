import type { Metadata } from "next";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { DirectoryHero } from "@/components/directory-hero";
import { DirectoryList } from "@/components/directory-list";
import { DirectoryRecovery } from "@/components/directory-recovery";
import { DirectoryEmpty, DirectoryNote } from "@/components/directory-notes";
import { fetchDirectory } from "@/lib/directory";

export const metadata: Metadata = {
  title: "Find Pet Care Near You | MetroPaws Wellness Club",
  description:
    "Veterinary clinics, groomers, pet stores, and boarding around Las Piñas, with addresses, phone numbers, and opening hours. A free community directory from MetroPaws Wellness Club.",
};

export default async function FindPetCarePage() {
  const directory = await fetchDirectory();

  return (
    <div className="flex flex-col min-h-svh overflow-x-clip">
      <SiteHeader />
      <main className="flex flex-col flex-1">
        <DirectoryHero />
        {/*
          A failed fetch hands over to the browser rather than rendering a dead
          end. This page is static with an hour-long revalidate window, so an
          error rendered here is an error cached for everyone who arrives in that
          hour; `DirectoryRecovery` fetches the listings at view time instead.
        */}
        {!directory.ok ? (
          <DirectoryRecovery />
        ) : directory.providers.length === 0 ? (
          <DirectoryEmpty />
        ) : (
          <DirectoryList providers={directory.providers} />
        )}
        <DirectoryNote />
      </main>
      <SiteFooter variant="photo" />
    </div>
  );
}
