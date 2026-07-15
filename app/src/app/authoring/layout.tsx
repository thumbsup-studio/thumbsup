import Link from "next/link";
import { RequireAdmin } from "@/features/auth/require-admin";

export default function AuthoringLayout({ children }: { children: React.ReactNode }) {
  return (
    <RequireAdmin>
      <div className="mx-auto min-h-dvh w-full max-w-4xl px-6 py-8">
        <header className="mb-6 flex items-center gap-6">
          <h1 className="text-lg font-bold text-ink">문제 저작</h1>
          <nav className="flex gap-4 text-sm text-ink-muted">
            <Link href="/authoring">Draft 목록</Link>
            <Link href="/authoring/quizzes">라이브 문제</Link>
          </nav>
        </header>
        {children}
      </div>
    </RequireAdmin>
  );
}
