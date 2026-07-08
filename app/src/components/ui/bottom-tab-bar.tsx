type Tab = { key: string; label: string; active?: boolean; onSelect?: () => void };

export function BottomTabBar({ tabs, ariaLabel = "하단 탭" }: { tabs: Tab[]; ariaLabel?: string }) {
  return (
    <nav
      aria-label={ariaLabel}
      className="sticky bottom-0 flex gap-2 rounded-card border border-border bg-surface p-2 shadow-card"
    >
      {tabs.map((tab) =>
        tab.active ? (
          <span
            key={tab.key}
            aria-current="page"
            className="flex min-h-12 flex-1 items-center justify-center rounded-control bg-primary px-3 py-3 text-sm font-semibold text-primary-fg"
          >
            {tab.label}
          </span>
        ) : (
          <button
            key={tab.key}
            type="button"
            onClick={tab.onSelect}
            className="flex min-h-12 flex-1 items-center justify-center rounded-control bg-surface-muted px-3 py-3 text-sm font-medium text-ink-muted transition-colors"
          >
            {tab.label}
          </button>
        ),
      )}
    </nav>
  );
}
