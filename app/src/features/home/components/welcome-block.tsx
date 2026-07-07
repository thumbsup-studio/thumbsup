import { getWelcomeCopy } from "@/features/home/home-logic";

type WelcomeBlockProps = {
  now: Date;
};

export function WelcomeBlock({ now }: WelcomeBlockProps) {
  const copy = getWelcomeCopy(now);

  return (
    <section className="space-y-3">
      <p className="text-sm font-semibold uppercase tracking-[0.2em] text-slate-500">
        {copy.eyebrow}
      </p>
      <div className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight text-slate-950">{copy.title}</h1>
        <p className="max-w-md text-sm leading-6 text-slate-600">{copy.body}</p>
      </div>
    </section>
  );
}
