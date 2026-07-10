/**
 * 꼬리질문 상세 API 소비 (GET /api/v1/follow-up-questions/{id}).
 *
 * 서버 응답이 이미 FollowUpQuestionDetail 모양이라 매핑 없이 그대로 반환한다.
 */

import type { FollowUpQuestionDetail } from "@/features/play/types";
import { apiRequest } from "@/lib/api";

export function fetchFollowUpQuestion(followUpQuestionId: number): Promise<FollowUpQuestionDetail> {
  return apiRequest<FollowUpQuestionDetail>(`/follow-up-questions/${followUpQuestionId}`);
}
