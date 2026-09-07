import { Card } from "@thumbsup/ui-web";
import type { Metadata } from "next";
import { AuthoringLoginForm } from "@/features/auth/authoring-login-form";

export const metadata: Metadata = {
  title: "로그인 · Thumbs Up 문제 저작",
  description: "Thumbs Up 관리자 문제 저작 도구에 로그인하세요.",
};

export default function LoginPage() {
  return (
    <main className="flex min-h-dvh flex-col px-6 py-10">
      <div className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center gap-8">
        <div className="flex flex-col gap-1 text-center">
          <h1 className="text-3xl font-extrabold tracking-tight text-ink">문제 저작</h1>
          <p className="text-base text-ink-muted">관리자 계정으로 로그인해 주세요.</p>
        </div>
        <Card>
          <AuthoringLoginForm />
        </Card>
      </div>
    </main>
  );
}
