"use client";

import { useRouter } from "next/navigation";
import { type FormEvent, useState } from "react";
import { CheckIcon, LockIcon, MailIcon } from "@/components/icons";
import { Button } from "@/components/ui/button";
import { Feedback } from "@/components/ui/feedback";
import { Input } from "@/components/ui/input";
import { ApiError, ErrorCode, NetworkError, signup } from "@/lib/api";
import { PlaceholderLink } from "./placeholder-link";
import { validateEmail, validatePassword, validatePasswordConfirm } from "./validation";

type FieldErrors = { email?: string; password?: string; confirm?: string };
type FormError = { title: string; description: string };

export function SignupForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [agreed, setAgreed] = useState(false);
  const [loading, setLoading] = useState(false);
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  const [formError, setFormError] = useState<FormError | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFieldErrors({});
    setFormError(null);

    const emailError = validateEmail(email);
    const passwordError = validatePassword(password);
    const confirmError = validatePasswordConfirm(password, confirm);
    if (emailError || passwordError || confirmError) {
      setFieldErrors({
        email: emailError ?? undefined,
        password: passwordError ?? undefined,
        confirm: confirmError ?? undefined,
      });
      if (passwordError) {
        setFormError({
          title: "비밀번호 형식이 올바르지 않아요",
          description: "8자 이상 72자 이하로 입력해 주세요.",
        });
      }
      return;
    }
    if (!agreed) {
      setFormError({
        title: "약관 동의가 필요해요",
        description: "이용약관 및 개인정보 처리방침에 동의해 주세요.",
      });
      return;
    }

    setLoading(true);
    try {
      await signup(email, password);
      // 가입 성공 = 자동 로그인(토큰 저장 완료). 신규 유저 → 온보딩(#17) 자리, 현재는 홈.
      router.push("/");
    } catch (error) {
      if (error instanceof ApiError) {
        if (error.is(ErrorCode.USER_EMAIL_DUPLICATED)) {
          setFieldErrors({ email: "이미 가입된 이메일이에요." });
          setFormError({
            title: "이미 가입된 이메일이에요",
            description: "다른 이메일로 시도하거나 로그인해 주세요.",
          });
        } else if (error.is(ErrorCode.INVALID_INPUT) && error.fieldErrors) {
          const mapped: FieldErrors = {};
          for (const fieldError of error.fieldErrors) {
            if (fieldError.field === "email") mapped.email = fieldError.reason;
            if (fieldError.field === "password") mapped.password = fieldError.reason;
          }
          setFieldErrors(mapped);
          setFormError({ title: "입력값을 다시 확인해 주세요", description: error.message });
        } else {
          setFormError({ title: "가입에 실패했어요", description: error.message });
        }
      } else if (error instanceof NetworkError) {
        setFormError({
          title: "네트워크에 연결할 수 없어요",
          description: "잠시 후 다시 시도해 주세요.",
        });
      } else {
        setFormError({
          title: "가입 중 문제가 발생했어요",
          description: "잠시 후 다시 시도해 주세요.",
        });
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
        error={fieldErrors.email}
        disabled={loading}
      />
      <Input
        label="비밀번호"
        type="password"
        name="password"
        autoComplete="new-password"
        placeholder="비밀번호를 입력하세요"
        leftIcon={<LockIcon className="size-5" />}
        value={password}
        onChange={(event) => setPassword(event.target.value)}
        error={fieldErrors.password}
        disabled={loading}
      />
      <Input
        label="비밀번호 확인"
        type="password"
        name="passwordConfirm"
        autoComplete="new-password"
        placeholder="비밀번호를 다시 입력"
        leftIcon={<LockIcon className="size-5" />}
        value={confirm}
        onChange={(event) => setConfirm(event.target.value)}
        error={fieldErrors.confirm}
        disabled={loading}
      />

      <label className="flex items-start gap-2 text-sm text-ink-muted">
        <span className="relative mt-0.5 inline-flex size-5 shrink-0">
          <input
            type="checkbox"
            checked={agreed}
            onChange={(event) => setAgreed(event.target.checked)}
            disabled={loading}
            className="peer size-5 appearance-none rounded-md border border-border bg-surface transition-colors checked:border-primary checked:bg-primary disabled:opacity-60"
          />
          <CheckIcon className="pointer-events-none absolute inset-0 m-auto size-3.5 text-primary-fg opacity-0 peer-checked:opacity-100" />
        </span>
        <span>
          <span className="font-semibold text-primary">(필수)</span>{" "}
          <PlaceholderLink
            message="이용약관은 아직 준비 중이에요."
            className="font-medium text-ink underline"
          >
            이용약관
          </PlaceholderLink>{" "}
          및{" "}
          <PlaceholderLink
            message="개인정보 처리방침은 아직 준비 중이에요."
            className="font-medium text-ink underline"
          >
            개인정보 처리방침
          </PlaceholderLink>
          에 동의합니다.
        </span>
      </label>

      {formError ? (
        <Feedback tone="error">
          <span className="flex flex-col">
            <strong className="font-semibold">{formError.title}</strong>
            <span className="text-ink-muted">{formError.description}</span>
          </span>
        </Feedback>
      ) : null}

      <Button type="submit" loading={loading} loadingText="가입 중…" className="w-full">
        가입하기
      </Button>
    </form>
  );
}
