import { Button } from "@/components/ui/button";
import { Chip } from "@/components/ui/chip";
import { MASTERY_LABEL } from "@/components/ui/graph-node";
import type { AtlasNode, MasteryLevel } from "@/features/atlas/types";

const MASTERY_CHIP_TONE: Record<MasteryLevel, "success" | "primary" | "neutral"> = {
  master: "success",
  learning: "primary",
  unlearned: "neutral",
};

type ConceptSheetProps = {
  node: AtlasNode;
  onReview: () => void;
};

export function ConceptSheet({ node, onReview }: ConceptSheetProps) {
  return (
    <section
      aria-label="선택한 개념"
      className="rounded-card border border-border bg-surface p-5 shadow-card"
    >
      <div className="flex items-center justify-between gap-3">
        <h3 className="text-lg font-semibold text-ink">{node.label}</h3>
        <Chip tone={MASTERY_CHIP_TONE[node.mastery]}>{MASTERY_LABEL[node.mastery]}</Chip>
      </div>
      <p className="mt-2 text-sm text-ink-muted">{node.summary}</p>
      <Button className="mt-4 w-full" onClick={onReview}>
        복습하기
      </Button>
    </section>
  );
}
