import type { Metadata } from "next";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { AboutHero } from "@/components/about-hero";
import { AboutMission } from "@/components/about-mission";
import { AboutOfferings } from "@/components/about-offerings";
import { AboutValues } from "@/components/about-values";

export const metadata: Metadata = {
  title: "About MetroPaws | Pet Wellness Club Philippines",
  description:
    "Learn about MetroPaws — our mission, what we offer, and the values that guide everything we do for pet families in Las Piñas and Metro Manila.",
};

export default function AboutPage() {
  return (
    <div className="flex flex-col min-h-svh overflow-x-clip">
      <SiteHeader />
      <main className="flex flex-col flex-1">
        <AboutHero />
        <AboutMission />
        <AboutOfferings />
        <AboutValues />
      </main>
      <SiteFooter variant="photo" />
    </div>
  );
}
