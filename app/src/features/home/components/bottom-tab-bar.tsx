"use client";

import Image from "next/image";

type BottomTabBarProps = {
  activeTab: "home" | "history" | "profile";
  onHistoryClick: () => void;
  onProfileClick: () => void;
};

type TabKey = "home" | "history" | "profile";

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
  "flex min-h-11 flex-1 flex-col items-center justify-center gap-1 rounded-2xl px-5 py-2 text-[0.72rem] font-medium transition";

function getTabClassName(isActive: boolean) {
  if (isActive) {
    return `${baseTabClassName} cursor-default text-slate-600`;
  }

  return `${baseTabClassName} text-slate-600 hover:bg-slate-100/90`;
}

export function BottomTabBar({
  activeTab,
  onHistoryClick,
  onProfileClick,
}: BottomTabBarProps) {
  return (
    <nav
      aria-label="하단 탭"
      className="flex gap-1.5 rounded-[26px] border border-slate-200/90 bg-white/90 p-1.5 shadow-[0_-10px_30px_rgba(15,23,42,0.08)] backdrop-blur"
    >
      <button
        aria-current={activeTab === "home" ? "page" : undefined}
        className={getTabClassName(activeTab === "home")}
        data-state={activeTab === "home" ? "active" : "inactive"}
        type="button"
      >
        <TabIcon active={activeTab === "home"} tab="home" />
        <span>홈</span>
      </button>
      <button
        aria-current={activeTab === "history" ? "page" : undefined}
        className={getTabClassName(activeTab === "history")}
        data-state={activeTab === "history" ? "active" : "inactive"}
        onClick={onHistoryClick}
        type="button"
      >
        <TabIcon active={activeTab === "history"} tab="history" />
        <span>히스토리</span>
      </button>
      <button
        aria-current={activeTab === "profile" ? "page" : undefined}
        className={getTabClassName(activeTab === "profile")}
        data-state={activeTab === "profile" ? "active" : "inactive"}
        onClick={onProfileClick}
        type="button"
      >
        <TabIcon active={activeTab === "profile"} tab="profile" />
        <span>프로필</span>
      </button>
    </nav>
  );
}
