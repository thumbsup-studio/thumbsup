export type HomeData = {
  streakDays: number;
  character: {
    name: string;
    fullness: number;
  };
  todayCourse: {
    title: string;
    subtitle: string;
    progress: number;
    total: number;
    durationLabel: string;
  };
};
