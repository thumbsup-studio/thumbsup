/**
 * 의견 보내기 API 소비 (POST /api/v1/feedbacks).
 * 인증 유저의 자유 텍스트 의견을 서버에 적재한다. 성공 시 생성된 id를 반환한다.
 */

import type { ApiRequest } from "./client";

export function createFeedbackApi(apiRequest: ApiRequest) {
  return {
    sendFeedback(content: string): Promise<{ id: number }> {
      return apiRequest<{ id: number }>("/feedbacks", { method: "POST", body: { content } });
    },
  };
}
