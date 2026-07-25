export function AboutHero() {
  return (
    <section className="bg-(--color-navy) py-24 md:py-36">
      <div className="max-w-6xl mx-auto px-6">
        <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold) mp-rise [animation-delay:60ms]">
          About MetroPaws
        </p>

        <h1 className="mt-6 text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight leading-tight text-white max-w-[22ch] mp-rise [animation-delay:200ms]">
          Not just a FACT...{" "}
          <span className="text-(--color-gold)">it&apos;s a PACK.</span>
        </h1>

        <div className="mt-10 w-16 h-0.5 bg-(--color-gold) mp-rule-draw [animation-delay:380ms]" />

        <p className="mt-10 text-sm leading-relaxed text-white/80 max-w-[55ch] mp-rise [animation-delay:520ms]">
          MetroPaws is an exclusive wellness club providing the 5K Shield — a premier
          emergency and routine care system designed for the discerning pet parent. We
          combine digital convenience with physical reliability to ensure your pet is
          protected 24/7.
        </p>
      </div>
    </section>
  );
}
