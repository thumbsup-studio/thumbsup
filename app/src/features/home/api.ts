/**
 * 홈 화면 API 소비 (GET /api/v1/home, GET·POST /api/v1/mascot).
 *
 * 홈은 두 엔드포인트를 합쳐 그린다 — /home(스트릭·포인트·학습 중인 코스 목록)과
 * /mascot(캐릭터 '보리' 이름·포만감)은 서로 다른 feature(quiz/mascot)라 응답도 분리돼 있다.
 * 앱 홈은 코스명을 카드 상단 라벨(title)로, 이어 배울 화 제목을 본문(subtitle)으로 쓰므로
 * 여기서 서버 응답을 프레젠테이션용 HomeData로 매핑한다.
 * (points는 현재 홈 UI에 표시 자리가 없어 매핑하지 않는다 — 자리 생기면 연결.)
 *
 * courses는 최근 푼 순 최대 10개이고 항상 1개 이상이다(신규 유저는 첫 코스 1개 — 서버 이슈 240 보장,
 * 빈 배열 방어 불필요). 코스가 아예 없는 운영 사고 시에만 404 COURSE_NOT_FOUND가 온다.
 */

import { formatDuration } from "@/features/home/home-logic";
import type { HomeData } from "@/features/home/types";
import { apiRequest } from "@/lib/api";

type HomeResponse = {
  streakDays: number;
  points: number;
  todayCompleted: boolean;
  courses: Array<{
    courseId: number;
    courseTitle: string;
    unitId: number;
    unitTitle: string;
    order: number;
    completedCount: number;
    totalCount: number;
    estimatedMinutes: number;
    completed: boolean;
  }>;
};

type MascotResponse = {
  name: string;
  fullness: number;
};

function toHomeData(home: HomeResponse, mascot: MascotResponse): HomeData {
  return {
    streakDays: home.streakDays,
    character: mascot,
    courses: home.courses.map((course) => ({
      courseId: course.courseId,
      title: course.courseTitle,
      subtitle: course.unitTitle,
      progress: course.completedCount,
      total: course.totalCount,
      completed: course.completed,
      durationLabel: formatDuration(course.estimatedMinutes),
    })),
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
