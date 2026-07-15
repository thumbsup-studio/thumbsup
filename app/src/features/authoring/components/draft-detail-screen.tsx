"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import { getDraft } from "@/features/authoring/api";
import { ApproveSheet } from "@/features/authoring/components/approve-sheet";
import { ReviewSheet } from "@/features/authoring/components/review-sheet";
import type {
  DraftDetail,
  DraftOrigin,
  DraftStatus,
  GeneratedFollowUpQuestion,
  GeneratedQuiz,
  GeneratedQuizKeyword,
} from "@/features/authoring/types";
import { ApiError } from "@/lib/api";

type LoadState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "success"; draft: DraftDetail };

const ORIGIN_LABEL: Record<DraftOrigin, string> = { NEW: "신규", IMPROVE: "개선" };
const STATUS_LABEL: Record<DraftStatus, string> = { DRAFT: "검토중", APPROVED: "승인됨" };

function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString("ko-KR", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

/** Draft 상세 화면 — payload 미리보기, 검수 이력, 검수/승인 액션(DRAFT 상태에서만 노출). */
export function DraftDetailScreen({ draftId }: { draftId: number }) {
  const router = useRouter();
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [reviewOpen, setReviewOpen] = useState(false);
  const [approveOpen, setApproveOpen] = useState(false);

  const load = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const draft = await getDraft(draftId);
      setState({ status: "success", draft });
    } catch (error) {
      // 재발급까지 실패한 세션 무효(401)는 로그인으로 유도(frontend-api 규칙 3). 그 외는 재시도 가능한 에러.
      if (error instanceof ApiError && error.status === 401) {
        router.replace("/login");
        return;
      }
      // 권한 없음(403) — RequireAdmin이 이미 진입을 막지만, role이 세션 중 바뀌는 경우를 대비한 방어.
      if (error instanceof ApiError && error.status === 403) {
        router.replace("/");
        return;
      }
      setState({ status: "error" });
    }
  }, [draftId, router]);

  useEffect(() => {
    void load();
  }, [load]);

  if (state.status === "loading") {
    return <DraftDetailSkeleton />;
  }

  if (state.status === "error") {
    return (
      <Feedback onRetry={() => void load()} tone="error">
        draft를 불러오지 못했어요.
      </Feedback>
    );
  }

  const { draft } = state;
  const sortedRevisions = [...draft.revisions].sort((a, b) => b.revisionNo - a.revisionNo);

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-wrap items-center gap-3">
        <h2 className="text-xl font-bold text-ink">{draft.topic}</h2>
        <Chip tone={draft.origin === "NEW" ? "primary" : "neutral"}>
          {ORIGIN_LABEL[draft.origin]}
        </Chip>
        <Chip tone={draft.status === "APPROVED" ? "success" : "neutral"}>
          {STATUS_LABEL[draft.status]}
        </Chip>
      </header>

      <section className="flex flex-col gap-3">
        {draft.payload.quizzes.map((quiz, index) => (
          <QuizPayloadCard
            key={`${quiz.type}-${quiz.questionText}`}
            quiz={quiz}
            slotOrder={index + 1}
          />
        ))}
      </section>

      <section className="flex flex-col gap-3">
        <h3 className="text-base font-bold text-ink">검수 이력</h3>
        {sortedRevisions.length === 0 ? (
          <p className="text-sm text-ink-muted">아직 검수 이력이 없어요.</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {sortedRevisions.map((revision) => (
              <li key={revision.revisionNo}>
                <Card className="flex flex-col gap-1">
                  <p className="text-xs font-semibold text-ink-muted">
                    #{revision.revisionNo} · {formatDateTime(revision.createdAt)}
                  </p>
                  <p className="text-sm text-ink">{revision.reviewSummary ?? "요약 없음"}</p>
                </Card>
              </li>
            ))}
          </ul>
        )}
      </section>

      {draft.status === "DRAFT" ? (
        <div className="flex gap-3">
          <Button onClick={() => setReviewOpen(true)} variant="secondary">
            검수 시작
          </Button>
          <Button onClick={() => setApproveOpen(true)}>승인</Button>
        </div>
      ) : null}

      <ReviewSheet draftId={draftId} onClose={() => setReviewOpen(false)} open={reviewOpen} />
      <ApproveSheet
        draftId={draftId}
        onApproved={() => void load()}
        onClose={() => setApproveOpen(false)}
        open={approveOpen}
      />
    </div>
  );
}

function QuizPayloadCard({ quiz, slotOrder }: { quiz: GeneratedQuiz; slotOrder: number }) {
  return (
    <Card className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <span className="text-sm font-semibold text-ink-muted">{slotOrder}</span>
        <Chip tone="neutral">{quiz.type}</Chip>
        <Chip tone="neutral">{quiz.difficulty}</Chip>
      </div>
      {/* [[마커]]는 사전 용어 표기 규칙(정확히 1회 등장) 검수 대상이라 변환 없이 원문 그대로 노출한다. */}
      <p className="text-base font-semibold text-ink">{quiz.questionText}</p>
      {quiz.codeSnippet ? (
        <pre className="overflow-x-auto rounded-control border border-border bg-ink px-4 py-3 text-primary-fg text-sm">
          <code>{quiz.codeSnippet}</code>
        </pre>
      ) : null}
      {quiz.choices ? (
        <ul className="flex flex-col gap-1.5">
          {quiz.choices.map((choice) => (
            <li
              className={`rounded-control px-3 py-2 text-sm ${
                choice.isCorrect
                  ? "bg-success/10 font-semibold text-success"
                  : "bg-surface-muted text-ink-muted"
              }`}
              key={choice.content}
            >
              {choice.content}
              {choice.isCorrect ? " (정답)" : null}
            </li>
          ))}
        </ul>
      ) : null}
      {/* choices가 없는 OX 문제는 이 표시가 화면상 유일한 정답 단서다. */}
      {quiz.correctAnswer ? (
        <p
          className={`rounded-control px-3 py-2 text-sm font-semibold ${
            quiz.correctAnswer === "O" ? "bg-success/10 text-success" : "bg-danger/10 text-danger"
          }`}
        >
          정답: {quiz.correctAnswer}
        </p>
      ) : null}
      {quiz.answerKeywords ? (
        <div className="flex flex-col gap-1.5">
          <span className="text-xs font-semibold text-ink-muted">정답(빈칸별 동의어)</span>
          <ul className="flex flex-col gap-1.5">
            {quiz.answerKeywords.map((synonyms, index) => (
              <li
                className="rounded-control bg-success/10 px-3 py-2 text-sm font-semibold text-success"
                key={synonyms.join("|")}
              >
                빈칸 {index + 1}: {synonyms.join(" / ")}
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      <div className="flex flex-col gap-3 border-border border-t pt-3">
        <ExplanationBlock label="요약" text={quiz.explanationSummary} />
        {quiz.explanationExample ? (
          <ExplanationBlock label="실무 예시" text={quiz.explanationExample} />
        ) : null}
        <ExplanationBlock label="오답 해설" text={quiz.wrongAnswerExplanation} />
      </div>

      {quiz.keywords ? (
        <div className="flex flex-col gap-1.5">
          <span className="text-xs font-semibold text-ink-muted">키워드</span>
          <KeywordDictionary keywords={quiz.keywords} />
        </div>
      ) : null}

      {quiz.derivedConcepts ? (
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs font-semibold text-ink-muted">파생 개념</span>
          {quiz.derivedConcepts.map((concept) => (
            <Chip key={concept} tone="neutral">
              {concept}
            </Chip>
          ))}
        </div>
      ) : null}

      {quiz.followUpQuestions && quiz.followUpQuestions.length > 0 ? (
        <details className="rounded-control border border-border bg-surface-muted px-3 py-2">
          <summary className="cursor-pointer text-sm font-semibold text-ink">
            꼬리질문 {quiz.followUpQuestions.length}개
          </summary>
          <ul className="mt-3 flex flex-col gap-3">
            {quiz.followUpQuestions.map((followUp) => (
              <FollowUpQuestionItem followUp={followUp} key={followUp.content} />
            ))}
          </ul>
        </details>
      ) : null}
    </Card>
  );
}

function FollowUpQuestionItem({ followUp }: { followUp: GeneratedFollowUpQuestion }) {
  return (
    <li className="flex flex-col gap-2 rounded-control bg-surface p-3">
      <div className="flex flex-wrap items-center gap-2">
        <p className="font-semibold text-ink text-sm">{followUp.content}</p>
        {followUp.isPrimary ? <Chip tone="primary">대표질문</Chip> : null}
        <Chip tone="neutral">{followUp.difficulty}</Chip>
      </div>
      <ExplanationBlock label="한 줄 답변" text={followUp.oneLineAnswer} />
      {followUp.blocks.map((block) => (
        <ExplanationBlock key={block.label} label={block.label} text={block.content} />
      ))}
      {followUp.keywords.length > 0 ? <KeywordDictionary keywords={followUp.keywords} /> : null}
    </li>
  );
}

function ExplanationBlock({ label, text }: { label: string; text: string }) {
  return (
    <div className="flex flex-col gap-1">
      <span className="text-xs font-semibold text-ink-muted">{label}</span>
      <p className="text-sm text-ink-muted">{text}</p>
    </div>
  );
}

function KeywordDictionary({ keywords }: { keywords: GeneratedQuizKeyword[] }) {
  return (
    <dl className="flex flex-col gap-1.5">
      {keywords.map((kw) => (
        <div
          className="flex flex-col gap-0.5 rounded-control bg-surface-muted px-3 py-2"
          key={kw.keyword}
        >
          <dt className="font-semibold text-ink text-sm">{kw.keyword}</dt>
          <dd className="text-ink-muted text-sm">{kw.description}</dd>
        </div>
      ))}
    </dl>
  );
}

function DraftDetailSkeleton() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-7 w-40" />
      {[0, 1, 2].map((row) => (
        <Skeleton className="h-24 w-full" key={row} />
      ))}
    </div>
  );
}
