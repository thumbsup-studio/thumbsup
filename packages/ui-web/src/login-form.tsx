"use client";

import { type FormEvent, useState } from "react";
import { Button } from "./button";
import { Feedback } from "./feedback";
import { Input } from "./input";
import { LockIcon, MailIcon, RotateCcwIcon } from "./internal/icons";

const FAIL_MESSAGE = "이메일 또는 비밀번호를 다시 확인하고 재시도해 주세요.";
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export type LoginFormProps = {
  onSubmit: (email: string, password: string) => Promise<void>;
  onForgotPassword?: () => void;
};

/** 웹 앱과 저작 앱이 공유하는 로그인 폼. 인증 후 이동 정책은 각 앱이 주입한다. */
export function LoginForm({ onSubmit, onForgotPassword }: LoginFormProps) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const hasError = errorMessage !== null;

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setErrorMessage(null);
    if (!EMAIL_RE.test(email.trim()) || password.length < 8 || password.length > 72) {
      setErrorMessage(FAIL_MESSAGE);
      return;
    }

    setLoading(true);
    try {
      await onSubmit(email, password);
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : "로그인 중 문제가 발생했어요.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <form className="flex flex-col gap-5" noValidate onSubmit={handleSubmit}>
      <Input
        autoComplete="email"
        disabled={loading}
        label="이메일"
        leftIcon={<MailIcon className="size-5" />}
        name="email"
        onChange={(event) => setEmail(event.target.value)}
        placeholder="you@example.com"
        type="email"
        value={email}
      />
      <div className="flex flex-col gap-1.5">
        <Input
          autoComplete="current-password"
          disabled={loading}
          error={hasError}
          label="비밀번호"
          leftIcon={<LockIcon className="size-5" />}
          name="password"
          onChange={(event) => setPassword(event.target.value)}
          placeholder="8자 이상 입력"
          type="password"
          value={password}
        />
        {onForgotPassword ? (
          <button
            className="self-end text-sm font-medium text-ink-muted"
            onClick={onForgotPassword}
            type="button"
          >
            비밀번호를 잊으셨나요?
          </button>
        ) : null}
      </div>
      {hasError ? (
        <Feedback tone="error">
          <span className="flex flex-col">
            <strong className="font-semibold">로그인에 실패했어요</strong>
            <span className="text-ink-muted">{errorMessage}</span>
          </span>
        </Feedback>
      ) : null}
      <Button className="w-full" loading={loading} loadingText="로그인 중…" type="submit">
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
