import type { Metadata } from "next";
import Link from "next/link";
import { ChevronLeftIcon } from "@/components/icons";
import { Card } from "@/components/ui/card";
import { AuthBrand } from "@/features/auth/auth-brand";
import { RedirectIfAuthenticated } from "@/features/auth/redirect-if-authenticated";
import { SignupForm } from "@/features/auth/signup-form";

export const metadata: Metadata = {
  title: "회원가입 · Thumbs Up",
  description: "이메일로 가입하고 CS 학습을 시작하세요.",
};

export default function SignupPage() {
  return (
    <main className="flex min-h-dvh flex-col px-6 py-10">
      <RedirectIfAuthenticated />
      <div className="mx-auto w-full max-w-sm">
        <Link
          href="/login"
          aria-label="뒤로 가기"
          className="-ml-2 inline-flex size-11 items-center justify-center rounded-control text-ink"
        >
          <ChevronLeftIcon className="size-6" />
        </Link>
      </div>
      <div className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center gap-8">
        <AuthBrand title="회원가입" subtitle="가입하고 CS 학습을 시작하세요." />
        <Card className="flex flex-col gap-5">
          <SignupForm />
        </Card>
      </div>
      <footer className="mx-auto mt-8 flex w-full max-w-sm justify-center text-center">
        <p className="text-sm text-ink-muted">
          이미 계정이 있으신가요?{" "}
          <Link href="/login" className="font-semibold text-primary">
            로그인
          </Link>
        </p>
      </footer>
    </main>
  );
}
