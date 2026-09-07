/**
 * 복습(완료 스텝 재풀이) 흐름의 URL 파라미터 규약을 한 곳에 모은다.
 *
 * 재풀이는 기존 문제풀이(`/play`)·해설(`/insight`) 화면을 그대로 재사용하되,
 * 진행 상태를 서버가 아니라 URL로 들고 다닌다 — "슬롯 1→5를 자유롭게":
 * 코스 탭(완료 스텝 클릭) → /play(slot 1) → /insight → /play(slot 2) → … → /insight(slot 5) → /history/done
 * 스텝 주제명(topic)도 URL로 이어받아 완료 요약까지 전달한다(무상태).
 *
 * 점수·연속 정답·미리보기 개념은 없다(이슈 313) — 이미 지나온 문제로 돌아가 다시 풀 수도 있으므로
 * "라이브/미리보기" 구분이 성립하지 않고, 매번 자유롭게 오가며 몇 번이든 다시 채점받을 수 있다.
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
  /** 완료 요약에 표시할 스텝 주제명 */
  topic: string;
};

export type ReviewSearchParams = {
  step?: string;
  slot?: string;
  topic?: string;
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
    topic: params?.topic ?? "",
  };
}

function buildHref(path: string, ctx: ReviewContext, extra?: Record<string, string>): string {
  const query = new URLSearchParams({
    step: String(ctx.step),
    slot: String(ctx.slot),
    topic: ctx.topic,
    ...extra,
  });
  return `${path}?${query.toString()}`;
}

/** 코스 탭에서 완료 스텝을 누르면 → 그 스텝의 슬롯 1부터 재풀이 시작. */
export function reviewStartHref(step: number, topic: string): string {
  return buildHref(REVIEW_PLAY_PATH, { step, slot: 1, topic });
}

/** 채점 직후 해설 화면으로. */
export function reviewInsightHref(
  ctx: ReviewContext,
  quizId: number,
  isCorrect: boolean,
  /** 해설 화면 연출용 추가 파라미터. 값이 undefined인 키는 URL에 싣지 않는다. */
  extra?: { retry?: string },
): string {
  return buildHref(REVIEW_INSIGHT_PATH, ctx, {
    quizId: String(quizId),
    correct: isCorrect ? "true" : "false",
    ...(extra?.retry ? { retry: extra.retry } : {}),
  });
}

/** 다음 슬롯 문제로 이동한다. */
export function reviewNextPlayHref(ctx: ReviewContext): string {
  return buildHref(REVIEW_PLAY_PATH, { ...ctx, slot: ctx.slot + 1 });
}

/** 이전 슬롯 문제로 이동한다. */
export function reviewPreviousPlayHref(ctx: ReviewContext): string {
  return buildHref(REVIEW_PLAY_PATH, { ...ctx, slot: ctx.slot - 1 });
}

/** 마지막 슬롯 해설 → 복습 완료 요약으로. */
export function reviewDoneHref(ctx: ReviewContext): string {
  return buildHref(REVIEW_DONE_PATH, ctx);
}

/** 현재 슬롯이 이번 재풀이의 마지막(5번째)인지. */
export function isLastReviewSlot(ctx: ReviewContext): boolean {
  return ctx.slot >= REVIEW_STEP_TOTAL;
}
