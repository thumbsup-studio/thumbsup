import { getWelcomeCopy } from "@/features/home/home-logic";

type WelcomeBlockProps = {
  now: Date;
};

export function WelcomeBlock({ now }: WelcomeBlockProps) {
  const copy = getWelcomeCopy(now);

  return (
    <section className="min-w-0">
      <h1 className="text-2xl font-semibold tracking-tight text-ink">
        <span className="block text-balance">{copy.titleTop}</span>
        <span className="mt-1 block text-balance text-ink-muted">{copy.titleBottom}</span>
      </h1>
    </section>
  );
}
