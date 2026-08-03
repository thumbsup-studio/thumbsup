export type HomeCourse = {
  courseId: number;
  title: string;
  subtitle: string;
  progress: number;
  total: number;
  durationLabel: string;
};

export type HomeData = {
  streakDays: number;
  todayCompleted: boolean;
  character: {
    name: string;
    fullness: number;
  };
  /** 학습 중인 코스(최근 푼 순, 서버가 최대 10개·최소 1개 보장 — 이슈 240). */
  courses: HomeCourse[];
};
