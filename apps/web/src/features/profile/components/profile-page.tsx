"use client";

import { useRouter } from "next/navigation";
import { type ComponentType, useEffect, useRef, useState } from "react";
import { AppTabBar } from "@/components/app-tab-bar";
import {
  BellIcon,
  ChevronRightIcon,
  CircleCheckIcon,
  LogOutIcon,
  MessageSquareIcon,
  SpinnerIcon,
  TargetIcon,
  UserIcon,
} from "@/components/icons";
import { BottomSheet } from "@/components/ui/bottom-sheet";
import { Button } from "@/components/ui/button";
import { FeedbackSheet } from "@/features/profile/components/feedback-sheet";
import type { ProfileData } from "@/features/profile/types";
import { logout } from "@/lib/api";
import { useAppToast } from "@/providers/app-toast-provider";

type SettingItem = {
  key: string;
  label: string;
  icon: ComponentType<{ className?: string }>;
  /** 아직 화면이 없어 탭 시 띄우는 "준비 중" 안내(조사까지 맞춰 전달) */
  pendingMessage: string;
};

/** 아직 별도 이슈로 남은 설정 화면들 — 탭하면 앱 관례대로 "준비 중" 토스트를 띄운다. */
const SETTING_ITEMS: SettingItem[] = [
  {
    key: "account",
    label: "계정 설정",
    icon: UserIcon,
    pendingMessage: "계정 설정은 준비 중입니다.",
  },
  {
    key: "notifications",
    label: "알림",
    icon: BellIcon,
    pendingMessage: "알림 설정은 준비 중입니다.",
  },
  {
    key: "goals",
    label: "학습 목표",
    icon: TargetIcon,
    pendingMessage: "학습 목표는 준비 중입니다.",
  },
];

export function ProfilePage({ data }: { data: ProfileData }) {
  const router = useRouter();
  const { showToast } = useAppToast();
  const [sheetOpen, setSheetOpen] = useState(false);
  const [feedbackOpen, setFeedbackOpen] = useState(false);
  const [loggingOut, setLoggingOut] = useState(false);
  const [loggedOut, setLoggedOut] = useState(false);

  const initial = data.email.trim().charAt(0).toUpperCase() || "?";

  const doneRef = useRef<HTMLDivElement>(null);
  // 로그아웃 완료 오버레이가 뜨면 그 안의 버튼으로 포커스를 옮긴다(가려진 배경 컨트롤 탐색 방지).
  useEffect(() => {
    if (loggedOut) {
      doneRef.current?.querySelector<HTMLButtonElement>("button")?.focus();
    }
  }, [loggedOut]);

  // 준비 중 항목(토스트) + 의견 보내기(시트)를 한 리스트로 렌더한다.
  const settingRows = [
    ...SETTING_ITEMS.map((item) => ({
      key: item.key,
      label: item.label,
      icon: item.icon,
      onClick: () => showToast({ message: item.pendingMessage }),
    })),
    {
      key: "feedback",
      label: "의견 보내기",
      icon: MessageSquareIcon,
      onClick: () => setFeedbackOpen(true),
    },
  ];

  const confirmLogout = async () => {
    setLoggingOut(true);
    // logout()은 서버 폐기 실패와 무관하게 로컬 토큰을 비운다 → 사용자 관점에선 항상 성공.
    await logout();
    setLoggingOut(false);
    setSheetOpen(false);
    setLoggedOut(true);
  };

  return (
    <main className="flex min-h-dvh flex-col bg-bg text-ink">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-4 px-4 pt-6 pb-7 sm:px-6">
        {/* 신원 카드 — 서버에 이름/아바타가 없어 이메일 이니셜 + 이메일로 구성 */}
        <section className="flex flex-col items-center rounded-card border border-border/80 bg-surface p-6 text-center shadow-card">
          <div
            aria-hidden="true"
            className="flex size-22 items-center justify-center rounded-chip bg-primary text-3xl font-extrabold text-primary-fg shadow-hero"
          >
            {initial}
          </div>
          <p className="mt-4 text-lg font-bold break-all text-ink">{data.email}</p>
        </section>

        {/* 설정 리스트 — 미구현 항목은 준비 중 토스트 */}
        <section className="overflow-hidden rounded-card border border-border/80 bg-surface shadow-card">
          {settingRows.map((row, index) => {
            const Icon = row.icon;
            return (
              <button
                key={row.key}
                type="button"
                onClick={row.onClick}
                className={`flex min-h-14 w-full items-center gap-3.5 px-5 py-4 text-left transition-colors hover:bg-surface-muted ${
                  index < settingRows.length - 1 ? "border-b border-border" : ""
                }`}
              >
                <Icon className="size-5 text-ink-muted" />
                <span className="flex-1 text-base font-semibold text-ink">{row.label}</span>
                <ChevronRightIcon className="size-4.5 text-ink-muted" />
              </button>
            );
          })}
        </section>

        {/* 로그아웃 — 유일하게 실제 동작하는 액션 */}
        <button
          type="button"
          onClick={() => setSheetOpen(true)}
          className="flex min-h-14 w-full items-center justify-center gap-2 rounded-control bg-danger text-base font-bold text-primary-fg transition-colors hover:bg-danger/90"
        >
          <LogOutIcon className="size-5" />
          로그아웃
        </button>

        <p className="text-center text-xs text-ink-muted">Thumbs Up</p>

        <div className="sticky bottom-4 mt-auto pt-1">
          <AppTabBar activeTab="profile" />
        </div>
      </div>

      <BottomSheet open={sheetOpen} onClose={() => setSheetOpen(false)} title="로그아웃 확인">
        <div className="text-center">
          <div
            aria-hidden="true"
            className="mx-auto flex size-13 items-center justify-center rounded-chip bg-danger/10 text-danger"
          >
            <LogOutIcon className="size-6" />
          </div>
          <p className="mt-4 text-xl font-extrabold text-ink">로그아웃할까요?</p>
          <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">
            다시 이용하려면 이메일로 로그인해야 해요.
          </p>
          <div className="mt-6 flex flex-col gap-2.5">
            <button
              type="button"
              onClick={() => void confirmLogout()}
              disabled={loggingOut}
              aria-busy={loggingOut}
              className="flex min-h-14 w-full items-center justify-center gap-2 rounded-control bg-danger text-base font-bold text-primary-fg transition-colors hover:bg-danger/90 disabled:pointer-events-none disabled:opacity-60"
            >
              {loggingOut ? (
                <>
                  <SpinnerIcon className="size-5" />
                  로그아웃 중…
                </>
              ) : (
                "로그아웃"
              )}
            </button>
            <button
              type="button"
              onClick={() => setSheetOpen(false)}
              disabled={loggingOut}
              className="min-h-14 w-full rounded-control border border-border bg-surface text-base font-bold text-ink transition-colors hover:bg-surface-muted disabled:opacity-60"
            >
              취소
            </button>
          </div>
        </div>
      </BottomSheet>

      <FeedbackSheet open={feedbackOpen} onClose={() => setFeedbackOpen(false)} />

      {loggedOut ? (
        <div
          ref={doneRef}
          aria-label="로그아웃 완료"
          aria-modal="true"
          className="fixed inset-0 z-50 flex flex-col items-center justify-center bg-bg px-8 text-center motion-safe:animate-overlay-fade"
          role="dialog"
        >
          <div
            aria-hidden="true"
            className="flex size-18 items-center justify-center rounded-chip bg-success/10 text-success"
          >
            <CircleCheckIcon className="size-9" />
          </div>
          <p className="mt-5 text-2xl font-extrabold text-ink">로그아웃되었습니다</p>
          <p className="mt-2 text-base leading-relaxed text-ink-muted">
            그동안의 학습 기록은 안전하게 저장돼요.
            <br />
            다시 만나요.
          </p>
          <Button className="mt-8 w-full max-w-xs" onClick={() => router.replace("/login")}>
            로그인 화면으로
          </Button>
        </div>
      ) : null}
    </main>
  );
}
