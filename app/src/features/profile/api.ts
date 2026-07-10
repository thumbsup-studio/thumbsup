/**
 * 프로필 화면 API 소비 (GET /api/v1/auth/me).
 *
 * 서버 User는 이메일만 보유한다(이름·닉네임 없음) → 신원 표시는 이메일 하나로 한다.
 * 토큰은 localStorage(클라이언트 전용)라 이 조회는 RequireAuth 통과 후 클라이언트에서 실행된다.
 */

import type { ProfileData } from "@/features/profile/types";
import { apiRequest } from "@/lib/api";

type MeResponse = { email: string };

export async function fetchMe(): Promise<ProfileData> {
  const res = await apiRequest<MeResponse>("/auth/me");
  return { email: res.email };
}
