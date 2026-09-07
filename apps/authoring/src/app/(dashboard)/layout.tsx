import Link from "next/link";
import { LogoutButton } from "@/features/auth/logout-button";
import { RequireAdmin } from "@/features/auth/require-admin";

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <RequireAdmin>
      <div className="mx-auto min-h-dvh w-full max-w-4xl px-6 py-8">
        <header className="mb-6 flex flex-wrap items-center gap-3 sm:gap-6">
          <h1 className="text-lg font-bold text-ink">문제 저작</h1>
          <nav className="flex gap-4 text-sm text-ink-muted">
            <Link href="/">Draft 목록</Link>
            <Link href="/quizzes">라이브 문제</Link>
          </nav>
          <LogoutButton />
        </header>
        {children}
      </div>
    </RequireAdmin>
  );
}
