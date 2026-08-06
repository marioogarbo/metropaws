import { SiteHeader } from "@/components/site-header";
import { HeroSection } from "@/components/hero-section";
import { LogoMarquee } from "@/components/logo-marquee";
import { HowItWorksSection } from "@/components/how-it-works-section";
import { CoverageTeaser } from "@/components/coverage-teaser";
import { PlansSection } from "@/components/plans-section";
import { HowToPayRail } from "@/components/how-to-pay-rail";
import { PawPointsSection } from "@/components/pawpoints-section";
import { CommunitySection } from "@/components/community-section";
import { FoundingSection } from "@/components/founding-section";
import { FaqSection } from "@/components/faq-section";
import { SiteFooter } from "@/components/site-footer";
import { PartnerClinicCta } from "@/components/partner-clinic-cta";

export default function Home() {
  return (
    <div className="flex flex-col min-h-svh overflow-x-clip">
      <SiteHeader />
      <main className="flex flex-col flex-1">
        <HeroSection />
        <LogoMarquee />
        {/*
          AppPreviewSection is off the page on the client's instruction
          (2026-08-07) because its screenshots are stale: they show per-service
          session counts ("Vaccines 1 left") and a Book tab, neither of which the
          app has any more. The app now shows two peso benefits and a Claim tab.
          The component is left in place: re-capture public/mobile-app-*.jpg from
          the current build and put it back.
        */}
        <HowItWorksSection />
        <CoverageTeaser />
        <PlansSection />
        <HowToPayRail />
        <PawPointsSection />
        <CommunitySection />
        <FoundingSection />
        <FaqSection />
        <PartnerClinicCta />
      </main>

      <SiteFooter variant="photo" />
    </div>
  );
}
