export type QaRoute = {
  /** 검사할 라우트 경로 */
  path: string;
  /** 원본 디자인 시안 이미지 경로(app/ 기준 상대). null이면 휴리스틱 모드. #38 이후 시안이 생기면 지정 → 시안 대조 모드 */
  design: string | null;
};

export const qaRoutes: QaRoute[] = [
  { path: "/", design: "e2e/designs/home.png" },
  { path: "/play", design: null },
  { path: "/insight?question=0&correct=true", design: null },
  // 예) #38 이후: { path: "/quiz", design: "e2e/designs/quiz.png" },
];
