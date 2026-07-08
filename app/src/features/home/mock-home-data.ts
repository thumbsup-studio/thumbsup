import type { HomeData } from "@/features/home/types";

export const mockHomeData: HomeData = {
  streakDays: 12,
  todayCourse: {
    title: "운영체제",
    subtitle: "프로세스와 스레드",
    progress: 3,
    total: 8,
    durationLabel: "3분이면 끝나요",
  },
};
