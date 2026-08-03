import { apiRequest } from "./client";

export type CourseStepState = "COMPLETED" | "SOLVABLE" | "LOCKED";

export type CourseStep = {
  stepOrder: number;
  topic: string;
  estimatedMinutes: number;
  state: CourseStepState;
};

export type CourseItem = {
  courseId: number;
  title: string;
  category: string;
  steps: CourseStep[];
};

export type CourseListResponse = {
  items: CourseItem[];
};

/** 로그인 유저 기준 전체 코스 + 코스별 스텝 상태(완료/풀기/잠김) 목록. */
export function getCourses(): Promise<CourseListResponse> {
  return apiRequest<CourseListResponse>("/courses");
}
