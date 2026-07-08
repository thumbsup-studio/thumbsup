import type { Metadata } from "next";
import Link from "next/link";
import { Card } from "@/components/ui/card";
import { AuthBrand } from "@/features/auth/auth-brand";
import { LoginForm } from "@/features/auth/login-form";

export const metadata: Metadata = {
  title: "로그인 · Thumbs Up",
  description: "Thumbs Up에 로그인하고 오늘의 CS 문제를 이어가세요.",
};

export default function LoginPage() {
  return (
    <main className="flex min-h-dvh flex-col px-6 py-10">
      <div className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center gap-8">
        <AuthBrand title="Thumbs Up" subtitle="매일 한 문제, CS 감각이 쌓입니다." />
        <Card className="flex flex-col gap-5">
          <LoginForm />
        </Card>
      </div>
      <footer className="mx-auto mt-8 flex w-full max-w-sm flex-col items-center gap-3 text-center">
        <p className="text-sm text-ink-muted">
          계정이 없으신가요?{" "}
          <Link href="/signup" className="font-semibold text-primary">
            회원가입
          </Link>
        </p>
        <p className="text-xs text-ink-muted">
          계속하면{" "}
          <Link href="/terms" className="underline">
            이용약관
          </Link>
          과{" "}
          <Link href="/privacy" className="underline">
            개인정보 처리방침
          </Link>
          에 동의하게 됩니다. ·{" "}
          <Link href="/help" className="underline">
            도움말
          </Link>
        </p>
      </footer>
    </main>
  );
}
