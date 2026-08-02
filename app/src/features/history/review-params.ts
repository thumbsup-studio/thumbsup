/**
 * 복습(완료 스텝 재풀이) 흐름의 URL 파라미터 규약을 한 곳에 모은다.
 *
 * 재풀이는 기존 문제풀이(`/play`)·해설(`/insight`) 화면을 그대로 재사용하되,
 * 진행 상태를 서버가 아니라 URL로 들고 다닌다. 두 가지 모드가 있다:
 *   - 전체 복습: "슬롯 1→5를 순서대로" — 목록 → /play(slot 1) → /insight → /play(slot 2) → … → /insight(slot 5) → /history/done
 *   - 단건 복습(single=1): 고른 슬롯 하나만 풀고 곧장 /history/done으로 (다른 슬롯으로 이어지지 않음)
 * 정답 누계(rc), 연속 정답 수(rs), 스텝 주제명(topic)도 URL로 이어받아 완료 요약까지 전달한다(무상태).
 */

export const REVIEW_STEP_TOTAL = 5;

const REVIEW_PLAY_PATH = "/play";
const REVIEW_INSIGHT_PATH = "/insight";
const REVIEW_DONE_PATH = "/history/done";

export type ReviewContext = {
  /** 재풀이 중인 완료 스텝 번호 */
  step: number;
  /** 현재 문제의 슬롯 (1~REVIEW_STEP_TOTAL) */
  slot: number;
  /** 이번 스텝 재풀이에서 지금까지 맞힌 개수 */
  correct: number;
  /** 이번 스텝 재풀이에서 현재까지 이어진 연속 정답 수 */
  streak: number;
  /** 완료 요약에 표시할 스텝 주제명 */
  topic: string;
  /** true면 스텝 전체가 아니라 고른 문제 하나만 푸는 단건 복습 — 풀자마자 완료로 간다. */
  single: boolean;
};

export type ReviewSearchParams = {
  step?: string;
  slot?: string;
  rc?: string;
  rs?: string;
  topic?: string;
  single?: string;
};

function toInt(value: string | undefined, min: number): number | null {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= min ? Math.trunc(parsed) : null;
}

/** 라우트의 searchParams에서 복습 컨텍스트를 파싱한다. 복습 파라미터가 없으면 null(=일반 문제풀이). */
export function parseReviewContext(params: ReviewSearchParams | undefined): ReviewContext | null {
  const step = toInt(params?.step, 1);
  const slot = toInt(params?.slot, 1);
  if (step === null || slot === null) {
    return null;
  }

  return {
    step,
    slot,
    correct: toInt(params?.rc, 0) ?? 0,
    streak: toInt(params?.rs, 0) ?? 0,
    topic: params?.topic ?? "",
    single: params?.single === "1",
  };
}

function buildHref(path: string, ctx: ReviewContext, extra?: Record<string, string>): string {
  const query = new URLSearchParams({
    step: String(ctx.step),
    slot: String(ctx.slot),
    rc: String(ctx.correct),
    rs: String(ctx.streak),
    topic: ctx.topic,
    ...(ctx.single ? { single: "1" } : {}),
    ...extra,
  });
  return `${path}?${query.toString()}`;
}

/** 복습 목록 카드 → 해당 스텝의 슬롯 1부터 재풀이 시작(정답 누계 0). */
export function reviewStartHref(step: number, topic: string): string {
  return buildHref(REVIEW_PLAY_PATH, {
    step,
    slot: 1,
    correct: 0,
    streak: 0,
    topic,
    single: false,
  });
}

/** 문제 번호 선택 → 그 문제 하나만 재풀이. 풀면 곧장 완료 화면으로 간다(다른 슬롯으로 이어지지 않음). */
export function reviewSingleHref(step: number, slot: number, topic: string): string {
  return buildHref(REVIEW_PLAY_PATH, { step, slot, correct: 0, streak: 0, topic, single: true });
}

/** 채점 직후 해설 화면으로. correctAfter는 이 문제까지 포함한 누계. */
export function reviewInsightHref(
  ctx: ReviewContext,
  quizId: number,
  isCorrect: boolean,
  correctAfter: number,
  streakAfter: number,
): string {
  return buildHref(
    REVIEW_INSIGHT_PATH,
    { ...ctx, correct: correctAfter, streak: streakAfter },
    { quizId: String(quizId), correct: isCorrect ? "true" : "false" },
  );
}

/** 해설 → 다음 슬롯 문제로. 정답 누계는 그대로 이어받는다. */
export function reviewNextPlayHref(ctx: ReviewContext): string {
  return buildHref(REVIEW_PLAY_PATH, { ...ctx, slot: ctx.slot + 1 });
}

/** 마지막 슬롯 해설 → 복습 완료 요약으로. */
export function reviewDoneHref(ctx: ReviewContext): string {
  return buildHref(REVIEW_DONE_PATH, ctx);
}

/** 현재 슬롯이 이번 재풀이의 마지막인지 — 단건 복습은 항상 마지막, 전체 복습은 5번째 슬롯일 때. */
export function isLastReviewSlot(ctx: ReviewContext): boolean {
  return ctx.single || ctx.slot >= REVIEW_STEP_TOTAL;
}
