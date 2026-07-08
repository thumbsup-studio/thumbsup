export type HomeData = {
  streakDays: number;
  todayCourse: {
    title: string;
    subtitle: string;
    progress: number;
    total: number;
    durationLabel: string;
  };
};
