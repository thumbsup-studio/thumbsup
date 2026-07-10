/**
 * 홈 화면 API 소비 (GET /api/v1/home, GET·POST /api/v1/mascot).
 *
 * 홈은 두 엔드포인트를 합쳐 그린다 — /home(스트릭·포인트·오늘의 학습 진입점)과
 * /mascot(캐릭터 '보리' 이름·포만감)은 서로 다른 feature(quiz/mascot)라 응답도 분리돼 있다.
 * 앱 홈은 코스명을 상단 라벨(title)로, 오늘 배울 화 제목을 본문(subtitle)으로 쓰므로
 * 여기서 서버 응답을 프레젠테이션용 HomeData로 매핑한다.
 * (points는 현재 홈 UI에 표시 자리가 없어 매핑하지 않는다 — 자리 생기면 연결.)
 */

import { formatDuration } from "@/features/home/home-logic";
import type { HomeData } from "@/features/home/types";
import { apiRequest } from "@/lib/api";

type HomeResponse = {
  streakDays: number;
  points: number;
  today: {
    courseId: number;
    courseTitle: string;
    unitId: number;
    unitTitle: string;
    order: number;
    completedCount: number;
    totalCount: number;
    estimatedMinutes: number;
  };
};

type MascotResponse = {
  name: string;
  fullness: number;
};

function toHomeData(home: HomeResponse, mascot: MascotResponse): HomeData {
  return {
    streakDays: home.streakDays,
    character: mascot,
    todayCourse: {
      title: home.today.courseTitle,
      subtitle: home.today.unitTitle,
      progress: home.today.completedCount,
      total: home.today.totalCount,
      durationLabel: formatDuration(home.today.estimatedMinutes),
    },
  };
}

export async function fetchHome(): Promise<HomeData> {
  const [home, mascot] = await Promise.all([
    apiRequest<HomeResponse>("/home"),
    apiRequest<MascotResponse>("/mascot"),
  ]);
  return toHomeData(home, mascot);
}

/** 세션(퀴즈 5문제) 완료 시 호출 — 보리 포만감을 올린다. */
export async function feedMascot(): Promise<MascotResponse> {
  return apiRequest<MascotResponse>("/mascot/feed", { method: "POST" });
}
