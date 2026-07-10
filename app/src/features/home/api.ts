/**
 * 홈 화면 API 소비 (GET /api/v1/home).
 *
 * 서버는 스트릭·포인트·오늘의 학습 진입점을 코스/화(unit) 구조로 내려준다.
 * 앱 홈은 코스명을 상단 라벨(title)로, 오늘 배울 화 제목을 본문(subtitle)으로 쓰므로
 * 여기서 서버 응답을 프레젠테이션용 HomeData로 매핑한다.
 * (points는 현재 홈 UI에 표시 자리가 없어 매핑하지 않는다 — 자리 생기면 연결.)
 * (character는 서버가 아직 내려주지 않음(#35 백엔드 미구현) — 고정값으로 채워두고,
 * API 필드가 생기면 이 기본값을 응답 매핑으로 교체한다.)
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

/** 서버 API(#35)가 아직 없어 고정값 — 백엔드 연동 시 HomeResponse 필드로 교체. */
const PLACEHOLDER_CHARACTER = { name: "보리", fullness: 62 };

function toHomeData(res: HomeResponse): HomeData {
  return {
    streakDays: res.streakDays,
    character: PLACEHOLDER_CHARACTER,
    todayCourse: {
      title: res.today.courseTitle,
      subtitle: res.today.unitTitle,
      progress: res.today.completedCount,
      total: res.today.totalCount,
      durationLabel: formatDuration(res.today.estimatedMinutes),
    },
  };
}

export async function fetchHome(): Promise<HomeData> {
  return toHomeData(await apiRequest<HomeResponse>("/home"));
}
