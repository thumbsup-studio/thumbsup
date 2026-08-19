import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import type { QuizStepBriefingBlock, QuizStepBriefingBlockType } from "@/lib/api/quiz";

const BLOCK_LABEL: Record<QuizStepBriefingBlockType, string> = {
  CONCEPT: "핵심 개념",
  EXAMPLE: "예시",
  CAUTION: "주의",
};

const BLOCK_TONE: Record<QuizStepBriefingBlockType, "primary" | "success" | "danger"> = {
  CONCEPT: "primary",
  EXAMPLE: "success",
  CAUTION: "danger",
};

type BriefingContentProps = {
  summary: string;
  blocks: QuizStepBriefingBlock[];
  headingLevel?: "h2" | "h3" | "h4";
};

/** 학습 화면과 저작 검수 화면이 같은 순서·분류로 브리핑을 보여주는 공통 표현. */
export function BriefingContent({
  summary,
  blocks,
  headingLevel: Heading = "h2",
}: BriefingContentProps) {
  const orderedBlocks = [...blocks].sort((a, b) => a.displayOrder - b.displayOrder);

  return (
    <div className="flex flex-col gap-4">
      <Card variant="hero">
        <p className="text-xs font-semibold text-primary-fg/76">한눈에 보기</p>
        <p className="mt-2 break-keep text-lg font-semibold leading-relaxed">{summary}</p>
      </Card>

      <ol className="flex flex-col gap-3">
        {orderedBlocks.map((block) => (
          <li key={`${block.displayOrder}-${block.heading}`}>
            <Card className="flex flex-col gap-3">
              <div className="flex items-center justify-between gap-3">
                <Chip tone={BLOCK_TONE[block.type]}>{BLOCK_LABEL[block.type]}</Chip>
                <span className="text-xs font-semibold text-ink-muted">{block.displayOrder}</span>
              </div>
              <div className="flex flex-col gap-1.5">
                <Heading className="break-keep text-base font-bold text-ink">
                  {block.heading}
                </Heading>
                <p className="whitespace-pre-wrap break-keep text-sm leading-relaxed text-ink-muted">
                  {block.content}
                </p>
              </div>
            </Card>
          </li>
        ))}
      </ol>
    </div>
  );
}
