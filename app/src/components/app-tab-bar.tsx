"use client";

import Image from "next/image";
import { useRouter } from "next/navigation";
import { useAppToast } from "@/providers/app-toast-provider";

type TabKey = "home" | "history" | "profile";

type AppTabBarProps = {
  activeTab: TabKey;
};

const tabIcons: Record<TabKey, { empty: string; full: string }> = {
  home: {
    empty: "/icons/tabs/home-empty.png",
    full: "/icons/tabs/home-full.png",
  },
  history: {
    empty: "/icons/tabs/history-empty.png",
    full: "/icons/tabs/history-full.png",
  },
  profile: {
    empty: "/icons/tabs/profile-empty.png",
    full: "/icons/tabs/profile-full.png",
  },
};

const tabItems: { key: TabKey; label: string }[] = [
  { key: "home", label: "홈" },
  { key: "history", label: "히스토리" },
  { key: "profile", label: "프로필" },
];

function TabIcon({ active, tab }: { active: boolean; tab: TabKey }) {
  const variant = active ? "full" : "empty";
  const src = tabIcons[tab][variant];

  return (
    <span data-icon-variant={variant}>
      <Image
        alt=""
        aria-hidden="true"
        className="h-6 w-6"
        height={24}
        src={src}
        unoptimized
        width={24}
      />
    </span>
  );
}

const baseTabClassName =
  "flex min-h-11 flex-1 flex-col items-center justify-center gap-1 rounded-control px-5 py-2 text-xs font-medium transition";

function getTabClassName(isActive: boolean) {
  if (isActive) {
    return `${baseTabClassName} cursor-default text-ink-muted`;
  }

  return `${baseTabClassName} text-ink-muted hover:bg-surface-muted`;
}

/**
 * 앱 하단 탭 내비게이션 — 홈·히스토리·프로필. 라우팅을 내부화해 화면(홈·히스토리)이
 * `activeTab`만 넘기면 어디서든 동일하게 렌더/이동한다. 프로필은 아직 준비 중이라 토스트로 안내한다.
 */
export function AppTabBar({ activeTab }: AppTabBarProps) {
  const router = useRouter();
  const { showToast } = useAppToast();

  function handleSelect(key: TabKey) {
    if (key === activeTab) {
      return;
    }

    if (key === "home") {
      router.push("/");
      return;
    }

    if (key === "history") {
      router.push("/history");
      return;
    }

    showToast({ message: "프로필은 준비 중입니다." });
  }

  return (
    <nav
      aria-label="하단 탭"
      className="flex gap-1.5 rounded-card border border-border/90 bg-surface/90 p-1.5 shadow-card backdrop-blur"
    >
      {tabItems.map((tab) => {
        const isActive = tab.key === activeTab;

        return (
          <button
            key={tab.key}
            aria-current={isActive ? "page" : undefined}
            className={getTabClassName(isActive)}
            data-state={isActive ? "active" : "inactive"}
            onClick={() => handleSelect(tab.key)}
            type="button"
          >
            <TabIcon active={isActive} tab={tab.key} />
            <span>{tab.label}</span>
          </button>
        );
      })}
    </nav>
  );
}
