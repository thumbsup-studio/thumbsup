"use client";

import { useRouter } from "next/navigation";
import { type FormEvent, useState } from "react";
import { LockIcon, MailIcon, RotateCcwIcon } from "@/components/icons";
import { Button } from "@/components/ui/button";
import { Feedback } from "@/components/ui/feedback";
import { Input } from "@/components/ui/input";
import { ApiError, login, NetworkError } from "@/lib/api";
import { PlaceholderLink } from "./placeholder-link";
import { validateEmail, validatePassword } from "./validation";

const FAIL_MESSAGE = "이메일 또는 비밀번호를 다시 확인하고 재시도해 주세요.";

export function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const hasError = errorMessage !== null;

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setErrorMessage(null);

    // 형식 오류도 서버 401(원인 미구분)과 동일하게 통합 문구로 안내한다.
    if (validateEmail(email) || validatePassword(password)) {
      setErrorMessage(FAIL_MESSAGE);
      return;
    }

    setLoading(true);
    try {
      await login(email, password);
      // 기존 유저 → 홈(S2). 신규/기존 분기는 온보딩(#17) 도입 시 확장.
      router.push("/");
    } catch (error) {
      if (error instanceof ApiError) {
        setErrorMessage(FAIL_MESSAGE);
      } else if (error instanceof NetworkError) {
        setErrorMessage("네트워크에 연결할 수 없어요. 잠시 후 다시 시도해 주세요.");
      } else {
        setErrorMessage("로그인 중 문제가 발생했어요. 잠시 후 다시 시도해 주세요.");
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-5">
      <Input
        label="이메일"
        type="email"
        name="email"
        autoComplete="email"
        placeholder="you@example.com"
        leftIcon={<MailIcon className="size-5" />}
        value={email}
        onChange={(event) => setEmail(event.target.value)}
        disabled={loading}
      />

      <div className="flex flex-col gap-1.5">
        <Input
          label="비밀번호"
          type="password"
          name="password"
          autoComplete="current-password"
          placeholder="8자 이상 입력"
          leftIcon={<LockIcon className="size-5" />}
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          error={hasError}
          disabled={loading}
        />
        <PlaceholderLink
          message="비밀번호 찾기는 아직 준비 중이에요."
          className="self-end text-sm font-medium text-primary"
        >
          비밀번호를 잊으셨나요?
        </PlaceholderLink>
      </div>

      {hasError ? (
        <Feedback tone="error">
          <span className="flex flex-col">
            <strong className="font-semibold">로그인에 실패했어요</strong>
            <span className="text-ink-muted">{errorMessage}</span>
          </span>
        </Feedback>
      ) : null}

      <Button type="submit" loading={loading} loadingText="로그인 중…" className="w-full">
        {hasError ? (
          <>
            <RotateCcwIcon className="size-5" />
            다시 로그인
          </>
        ) : (
          "로그인"
        )}
      </Button>
    </form>
  );
}
