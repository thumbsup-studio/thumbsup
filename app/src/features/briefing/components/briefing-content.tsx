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
  /** 저작 검수는 전체 보기, 학습자 첫 진입은 요약 우선 보기로 구분한다. */
  variant?: "full" | "overview";
  expanded?: boolean;
};

/** 학습 화면과 저작 검수 화면이 같은 순서·분류로 브리핑을 보여주는 공통 표현. */
export function BriefingContent({
  summary,
  blocks,
  headingLevel: Heading = "h2",
  variant = "full",
  expanded = true,
}: BriefingContentProps) {
  const orderedBlocks = [...blocks].sort((a, b) => a.displayOrder - b.displayOrder);

  if (variant === "overview") {
    return (
      <section
        aria-labelledby="briefing-summary-heading"
        className="overflow-hidden rounded-card border border-border bg-surface shadow-card"
        id="briefing-content"
      >
        <div className="border-b border-border px-5 py-5">
          <p className="text-xs font-semibold tracking-wide text-ink-muted">오늘의 핵심</p>
          <h2
            className="mt-2 break-keep text-lg font-semibold leading-relaxed text-ink"
            id="briefing-summary-heading"
          >
            {summary}
          </h2>
        </div>
        <ol className="divide-y divide-border">
          {orderedBlocks.map((block) => (
            <li className="px-5 py-4" key={`${block.displayOrder}-${block.heading}`}>
              <div className="flex items-start gap-3">
                <span className="mt-0.5 shrink-0 text-xs font-semibold text-ink-muted">
                  {BLOCK_LABEL[block.type]}
                </span>
                <div className="min-w-0 flex-1">
                  <Heading className="break-keep text-base font-bold text-ink">
                    {block.heading}
                  </Heading>
                  {expanded ? (
                    <p className="mt-2 whitespace-pre-wrap break-keep text-sm leading-relaxed text-ink-muted">
                      {block.content}
                    </p>
                  ) : null}
                </div>
              </div>
            </li>
          ))}
        </ol>
      </section>
    );
  }

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
