export type HomeCourse = {
  courseId: number;
  title: string;
  subtitle: string;
  progress: number;
  total: number;
  /** 완주 여부 — 마지막 스텝 풀 차례와 구분하기 위한 서버 플래그. */
  completed: boolean;
  durationLabel: string;
};

export type HomeData = {
  streakDays: number;
  character: {
    name: string;
    fullness: number;
  };
  /** 학습 중인 코스(최근 푼 순, 서버가 최대 10개·최소 1개 보장 — 이슈 240). */
  courses: HomeCourse[];
};
