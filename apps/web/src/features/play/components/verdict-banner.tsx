"use client";

import { useEffect, useRef } from "react";
import { AlertCircleIcon } from "@/components/icons";
import { Chip } from "@/components/ui/chip";
import type { Celebration } from "@/features/play/celebration-logic";
import { fireConfetti } from "@/features/play/confetti";

/**
 * 해설 화면 맨 위의 정답/오답 배너.
 *
 * 보상의 순간을 여기 한 곳에 모은다 — 풀이 화면(S3)은 조작감을 맡고,
 * 터지는 연출은 전부 이 화면에서 처리한다.
 */

/** 체크가 그려지는 것처럼 보이게 하는 대시 길이. path 길이(약 26)보다 넉넉히 크면 된다. */
const CHECK_DASH_LENGTH = 100;

function DrawnCheck() {
  return (
    <svg
      aria-hidden="true"
      className="h-7 w-7"
      fill="none"
      focusable="false"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={2.5}
      viewBox="0 0 24 24"
    >
      <path
        className="animate-check-draw"
        d="M20 6 9 17l-5-5"
        strokeDasharray={CHECK_DASH_LENGTH}
      />
    </svg>
  );
}

type VerdictBannerProps = {
  celebration: Celebration;
  correct: boolean;
};

export function VerdictBanner({ celebration, correct }: VerdictBannerProps) {
  const hasFiredConfetti = useRef(false);

  useEffect(() => {
    if (celebration.tier !== "confetti" || hasFiredConfetti.current) {
      return;
    }

    // StrictMode가 이펙트를 두 번 돌려도 컨페티는 한 번만 터뜨린다.
    hasFiredConfetti.current = true;
    void fireConfetti();
  }, [celebration.tier]);

  const hasChips = celebration.badge !== null || celebration.comboCount >= 2;

  return (
    <div
      className={`animate-celebration-pop rounded-control border px-4 py-4 ${
        correct
          ? "border-success/20 bg-success/10 text-success"
          : "border-danger/20 bg-danger/10 text-danger"
      }`}
      data-testid="verdict-banner"
      data-tier={celebration.tier}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-start gap-3">
          {/* 색만으로 정오답을 구분하지 않는다 — 아이콘과 문구를 항상 함께 낸다. */}
          <span className="mt-0.5 shrink-0">
            {correct ? <DrawnCheck /> : <AlertCircleIcon className="h-7 w-7" />}
          </span>
          <div className="min-w-0">
            <p className="text-sm font-black">{correct ? "정답이에요" : "오답이에요"}</p>
            <p aria-live="polite" className="mt-1 text-sm font-semibold leading-6 text-ink-muted">
              {celebration.praise}
            </p>
            {hasChips ? (
              <div className="mt-2.5 flex flex-wrap items-center gap-2">
                {/* 1콤보에 "1콤보"는 어색하므로 2부터 그린다. */}
                {celebration.comboCount >= 2 ? (
                  <Chip className="animate-combo-bounce" tone="success">
                    {celebration.comboCount}콤보
                  </Chip>
                ) : null}
                {celebration.badge !== null ? (
                  <Chip className="animate-combo-bounce" tone="primary">
                    {celebration.badge}
                  </Chip>
                ) : null}
              </div>
            ) : null}
          </div>
        </div>
        {correct ? (
          <span className="shrink-0 rounded-chip bg-surface px-3 py-1.5 text-xs font-black text-success">
            +10P
          </span>
        ) : null}
      </div>
    </div>
  );
}
