import { getWelcomeCopy } from "@/features/home/home-logic";

type WelcomeBlockProps = {
  now: Date;
};

export function WelcomeBlock({ now }: WelcomeBlockProps) {
  const copy = getWelcomeCopy(now);

  return (
    <section className="min-w-0">
      <h1 className="text-[1.85rem] font-semibold leading-[1.12] tracking-tight text-slate-950">
        <span className="block text-balance">{copy.titleTop}</span>
        <span className="mt-1 block text-balance text-slate-700">{copy.titleBottom}</span>
      </h1>
    </section>
  );
}
