"use client";

import { LoginForm } from "@thumbsup/ui-web";
import { useRouter } from "next/navigation";
import { ApiError, getMyProfile, login, NetworkError, tokenStore } from "@/lib/api";

export function AuthoringLoginForm() {
  const router = useRouter();

  async function authenticate(email: string, password: string) {
    try {
      await login(email, password);
      const profile = await getMyProfile();
      if (profile.role !== "ADMIN") {
        await tokenStore.clear();
        throw new Error("관리자 계정만 문제 저작 도구에 로그인할 수 있어요.");
      }
      router.replace("/");
    } catch (error) {
      if (error instanceof ApiError) {
        throw new Error("이메일 또는 비밀번호를 다시 확인하고 재시도해 주세요.");
      }
      if (error instanceof NetworkError) {
        throw new Error("네트워크에 연결할 수 없어요. 잠시 후 다시 시도해 주세요.");
      }
      if (error instanceof Error) throw error;
      throw new Error("로그인 중 문제가 발생했어요. 잠시 후 다시 시도해 주세요.");
    }
  }

  return <LoginForm onSubmit={authenticate} />;
}
