"use client";

type BottomTabBarProps = {
  onHistoryClick: () => void;
  onProfileClick: () => void;
};

const baseTabClassName =
  "flex min-h-12 flex-1 items-center justify-center rounded-2xl px-3 py-3 text-sm font-medium transition";

export function BottomTabBar({ onHistoryClick, onProfileClick }: BottomTabBarProps) {
  return (
    <nav
      aria-label="하단 탭"
      className="sticky bottom-0 mt-auto flex gap-2 rounded-[28px] border border-slate-200 bg-white/92 p-2 shadow-[0_-8px_30px_rgba(15,23,42,0.08)] backdrop-blur"
    >
      <span aria-current="page" className={`${baseTabClassName} bg-slate-950 text-white`}>
        홈
      </span>
      <button
        className={`${baseTabClassName} bg-slate-100 text-slate-600`}
        onClick={onHistoryClick}
        type="button"
      >
        히스토리
      </button>
      <button
        className={`${baseTabClassName} bg-slate-100 text-slate-600`}
        onClick={onProfileClick}
        type="button"
      >
        프로필
      </button>
    </nav>
  );
}
