"use client";

import { LoginForm as SharedLoginForm } from "@thumbsup/ui-web";
import { useRouter } from "next/navigation";
import { ApiError, getMyProfile, login, NetworkError } from "@/lib/api";
import { useAppToast } from "@/providers/app-toast-provider";
import { getAuthoringUrl } from "./authoring-url";

export function LoginForm() {
  const router = useRouter();
  const { showToast } = useAppToast();

  async function authenticate(email: string, password: string) {
    try {
      await login(email, password);
    } catch (error) {
      if (error instanceof ApiError) {
        throw new Error("이메일 또는 비밀번호를 다시 확인하고 재시도해 주세요.");
      }
      if (error instanceof NetworkError) {
        throw new Error("네트워크에 연결할 수 없어요. 잠시 후 다시 시도해 주세요.");
      }
      throw new Error("로그인 중 문제가 발생했어요. 잠시 후 다시 시도해 주세요.");
    }

    // 저작 관리자(ADMIN)는 저작 대시보드로, 일반 유저는 홈(S2)으로.
    // role 조회 실패는 로그인 성공과 분리 — 홈으로 폴백한다.
    let destination = "/";
    try {
      const me = await getMyProfile();
      if (me.role === "ADMIN") {
        destination = getAuthoringUrl();
      }
    } catch {
      // role 확인 실패 시 홈으로(로그인 자체는 성공).
    }
    router.replace(destination);
  }

  return (
    <SharedLoginForm
      onForgotPassword={() => showToast({ message: "비밀번호 찾기는 아직 준비 중이에요." })}
      onSubmit={authenticate}
    />
  );
}
