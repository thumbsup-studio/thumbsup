/**
 * 코스 탭에서 진입한 세션이 /play·/insight·/follow-up 화면을 오갈 때
 * courseId를 URL로 이어받는 규약. 기본 코스로 진입했으면 courseId가 없고,
 * 그 경우 서버가 기본 코스를 쓴다.
 */

export type CourseSearchParams = {
  courseId?: string;
};

/** 코스 탭 화면으로 돌아가는 경로 — 코스 세션 완주·뒤로가기가 공통으로 쓴다. */
export const COURSE_LIST_PATH = "/course";

export function parseCourseId(value: string | undefined): number | undefined {
  const parsed = Number(value);

  return Number.isFinite(parsed) && parsed > 0 ? Math.trunc(parsed) : undefined;
}

/** 다음 문제 진입 경로 — courseId가 있으면 그 코스로, 없으면 기본 코스로(서버가 처리). */
export function buildPlayHref(courseId: number | undefined): string {
  return courseId ? `/play?courseId=${courseId}` : "/play";
}

/**
 * 해설 화면 URL 재구성 — quizId로 해설을 다시 불러오며, courseId가 있으면 그대로 유지한다.
 * 서버 컴포넌트(app/follow-up/page.tsx)와 클라이언트 컴포넌트(follow-up-page.tsx) 양쪽이 쓴다 —
 * "use client" 파일에 두면 서버 쪽에서 클라이언트 경계를 넘어 가져오게 되므로 이 중립 모듈에 둔다.
 */
export function getInsightHref(
  quizId: number | null,
  correct: boolean,
  correctStreak: number,
  courseId: number | undefined,
): string {
  const params = new URLSearchParams({
    quizId: String(quizId ?? ""),
    correct: correct ? "true" : "false",
    streak: String(correctStreak),
  });
  if (courseId) {
    params.set("courseId", String(courseId));
  }

  return `/insight?${params.toString()}`;
}
