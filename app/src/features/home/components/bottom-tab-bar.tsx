"use client";

type BottomTabBarProps = {
  onHistoryClick: () => void;
  onProfileClick: () => void;
};

function HomeIcon() {
  return (
    <svg aria-hidden="true" className="h-4 w-4" fill="none" viewBox="0 0 24 24">
      <path
        d="M4.75 10.25 12 4.75l7.25 5.5v8a1 1 0 0 1-1 1h-3.5v-5.5h-5.5v5.5h-3.5a1 1 0 0 1-1-1z"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="1.8"
      />
    </svg>
  );
}

function HistoryIcon() {
  return (
    <svg aria-hidden="true" className="h-4 w-4" fill="none" viewBox="0 0 24 24">
      <path
        d="M4.75 12a7.25 7.25 0 1 0 2.1-5.15M4.75 4.75v3.9h3.9M12 8.5V12l2.5 2.5"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="1.8"
      />
    </svg>
  );
}

function ProfileIcon() {
  return (
    <svg aria-hidden="true" className="h-4 w-4" fill="none" viewBox="0 0 24 24">
      <path
        d="M12 12a3.25 3.25 0 1 0 0-6.5 3.25 3.25 0 0 0 0 6.5Zm-5.75 6.25a5.75 5.75 0 0 1 11.5 0"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="1.8"
      />
    </svg>
  );
}

const baseTabClassName =
  "flex min-h-11 flex-1 flex-col items-center justify-center gap-1 rounded-2xl px-2 py-2 text-[0.72rem] font-medium transition";

export function BottomTabBar({ onHistoryClick, onProfileClick }: BottomTabBarProps) {
  return (
    <nav
      aria-label="하단 탭"
      className="sticky bottom-0 mt-auto flex gap-1.5 rounded-[26px] border border-slate-200/90 bg-white/90 p-1.5 shadow-[0_-10px_30px_rgba(15,23,42,0.08)] backdrop-blur"
    >
      <span
        aria-current="page"
        className={`${baseTabClassName} bg-slate-950 text-white shadow-[0_10px_20px_rgba(15,23,42,0.16)]`}
      >
        <HomeIcon />
        <span>홈</span>
      </span>
      <button
        className={`${baseTabClassName} text-slate-500 hover:bg-slate-100/90 hover:text-slate-700`}
        onClick={onHistoryClick}
        type="button"
      >
        <HistoryIcon />
        <span>히스토리</span>
      </button>
      <button
        className={`${baseTabClassName} text-slate-500 hover:bg-slate-100/90 hover:text-slate-700`}
        onClick={onProfileClick}
        type="button"
      >
        <ProfileIcon />
        <span>프로필</span>
      </button>
    </nav>
  );
}
