"use client";

import { useEffect, useRef } from "react";
import { AlertCircleIcon, CheckIcon } from "@/components/icons";
import { Chip } from "@/components/ui/chip";
import type { Celebration } from "@/features/play/celebration-logic";

/**
 * 컨페티 색은 globals.css @theme 토큰에서 런타임에 읽는다.
 * 소스에 raw hex를 넣으면 check:design 게이트가 막고, 토큰이 바뀌어도 연출이 따라오지 않는다.
 */
const CONFETTI_COLOR_TOKENS = ["--color-primary", "--color-accent", "--color-ox-o"] as const;

function readTokenColors(): string[] {
  const styles = getComputedStyle(document.documentElement);

  return CONFETTI_COLOR_TOKENS.map((token) => styles.getPropertyValue(token).trim()).filter(
    (color) => color.length > 0,
  );
}

async function fireConfetti() {
  // 토큰을 못 읽으면 컨페티를 생략한다 — 하드코딩 색으로 때우지 않는다.
  const colors = readTokenColors();
  if (colors.length === 0) {
    return;
  }

  try {
    const { default: confetti } = await import("canvas-confetti");
    confetti({
      colors,
      disableForReducedMotion: true,
      origin: { x: 0.5, y: 0.62 },
      particleCount: 60,
      spread: 70,
      startVelocity: 32,
      ticks: 120,
    });
  } catch {
    // 지연 로드 실패는 연출만 생략한다 — 채점 흐름을 막으면 안 된다.
  }
}

type CelebrationOverlayProps = {
  celebration: Celebration;
  /** 유지 시간을 기다리지 않고 해설로 넘어간다. 중복 호출은 호출부가 막는다. */
  onContinue: () => void;
};

export function CelebrationOverlay({ celebration, onContinue }: CelebrationOverlayProps) {
  const hasFiredConfetti = useRef(false);

  useEffect(() => {
    if (celebration.tier !== "confetti" || hasFiredConfetti.current) {
      return;
    }

    // StrictMode가 이펙트를 두 번 돌려도 컨페티는 한 번만 터뜨린다.
    hasFiredConfetti.current = true;
    void fireConfetti();
  }, [celebration.tier]);

  const isCorrect = celebration.tier !== "none";

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-ink/20 px-4 pb-6"
      data-testid="celebration-overlay"
      data-tier={celebration.tier}
    >
      <div
        aria-live="polite"
        className="flex w-full max-w-md animate-celebration-pop flex-col items-center gap-3 rounded-card border border-border bg-surface px-5 py-6 shadow-card"
        role="status"
      >
        {/* 색만으로 정오답을 구분하지 않는다 — 아이콘과 문구를 항상 함께 낸다. */}
        <span
          className={`grid h-14 w-14 place-items-center rounded-chip ${
            isCorrect ? "bg-success/10 text-success" : "bg-danger/10 text-danger"
          }`}
        >
          {isCorrect ? <CheckIcon className="h-7 w-7" /> : <AlertCircleIcon className="h-7 w-7" />}
        </span>

        <p className="text-center text-base font-black text-ink">{celebration.praise}</p>

        {celebration.badge !== null || celebration.comboCount >= 2 ? (
          <div className="flex flex-wrap items-center justify-center gap-2">
            {celebration.badge !== null ? (
              <Chip className="animate-combo-bounce" tone="primary">
                {celebration.badge}
              </Chip>
            ) : null}
            {/* 1콤보에 "1콤보"는 어색하므로 2부터 그린다. */}
            {celebration.comboCount >= 2 ? (
              <Chip className="animate-combo-bounce" tone="success">
                {celebration.comboCount}콤보
              </Chip>
            ) : null}
          </div>
        ) : null}

        <button
          className="mt-1 flex min-h-12 w-full items-center justify-center rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero"
          onClick={onContinue}
          type="button"
        >
          계속
        </button>
      </div>
    </div>
  );
}
