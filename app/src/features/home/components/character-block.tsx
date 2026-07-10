import { DogIcon } from "@/components/icons";
import { formatFullness, getCharacterMood } from "@/features/home/home-logic";

type CharacterBlockProps = {
  name: string;
  fullness: number;
};

const RING_RADIUS = 28;
const RING_CIRCUMFERENCE = 2 * Math.PI * RING_RADIUS;

export function CharacterBlock({ name, fullness }: CharacterBlockProps) {
  const clamped = Math.min(100, Math.max(0, Math.round(fullness)));
  const ringOffset = RING_CIRCUMFERENCE * (1 - clamped / 100);
  const mood = getCharacterMood(clamped);

  return (
    <section
      aria-label={`캐릭터 ${name}, ${formatFullness(fullness)}`}
      className="flex flex-col items-center gap-3 rounded-card border border-border bg-surface p-6 text-center shadow-card"
    >
      <div className="relative flex size-36 items-center justify-center">
        <svg
          aria-hidden="true"
          className="absolute inset-0 size-36 -rotate-90"
          viewBox="0 0 64 64"
        >
          <circle
            className="stroke-surface-muted"
            cx={32}
            cy={32}
            fill="none"
            r={RING_RADIUS}
            strokeWidth={5}
          />
          <circle
            className="stroke-primary"
            cx={32}
            cy={32}
            fill="none"
            r={RING_RADIUS}
            strokeDasharray={RING_CIRCUMFERENCE}
            strokeDashoffset={ringOffset}
            strokeLinecap="round"
            strokeWidth={5}
          />
        </svg>
        <DogIcon className="size-28" mood={mood} />
      </div>
      <p className="text-lg font-semibold text-ink">{name}</p>
      <div>
        <p className="text-xs font-medium text-ink-muted">포만감</p>
        <p className="text-sm font-semibold text-ink">{clamped}%</p>
      </div>
    </section>
  );
}
