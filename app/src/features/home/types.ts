export type HomeData = {
  streakDays: number;
  todayCompleted: boolean;
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
