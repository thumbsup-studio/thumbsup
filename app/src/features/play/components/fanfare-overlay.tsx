"use client";

import { type DotLottie, DotLottieReact } from "@lottiefiles/dotlottie-react";
import { useEffect, useState } from "react";
import {
  hasPlayedCompletionFanfare,
  markCompletionFanfarePlayed,
} from "@/features/play/completion-params";
import { usePrefersReducedMotion } from "@/features/play/use-prefers-reduced-motion";

const FANFARE_SRC = "/lottie/fanfare.lottie";
const FANFARE_VERTICAL_SRC = "/lottie/fanfare-vertical.lottie";

/** 사다리 꼭대기는 두 애니메이션을 겹쳐 가장 크게 터뜨린다. */
const FANFARE_SOURCES = [FANFARE_SRC, FANFARE_VERTICAL_SRC] as const;
const COMPLETE_SOURCE = FANFARE_VERTICAL_SRC;

type FanfareOverlayProps = {
  /** 같은 판에서 두 번 터지지 않게 하는 식별자. 예: `daily:123`, `review:4`. */
  playKey: string;
};

export function FanfareOverlay({ playKey }: FanfareOverlayProps) {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [player, setPlayer] = useState<DotLottie | null>(null);
  const [isDismissed, setIsDismissed] = useState(false);
  // 뒤로가기·새로고침으로 다시 들어와도 축하를 반복하지 않는다.
  // 첫 렌더에서 sessionStorage를 읽으면 SSR과 어긋나므로 마운트 후에 판정한다.
  const [hasChecked, setHasChecked] = useState(false);
  const [shouldPlay, setShouldPlay] = useState(false);

  useEffect(() => {
    // 첫 이펙트는 훅의 상태가 갱신되기 전일 수 있어 matchMedia를 한 번 더 직접 확인한다.
    const reduceMotionNow =
      typeof window.matchMedia === "function" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReducedMotion || reduceMotionNow) {
      setHasChecked(true);
      setShouldPlay(false);
      return;
    }

    const alreadyPlayed = hasPlayedCompletionFanfare(playKey);
    if (!alreadyPlayed) {
      markCompletionFanfarePlayed(playKey);
    }

    setShouldPlay(!alreadyPlayed);
    setHasChecked(true);
  }, [playKey, prefersReducedMotion]);

  useEffect(() => {
    if (!player) {
      return undefined;
    }

    function dismiss() {
      setIsDismissed(true);
    }

    player.addEventListener("complete", dismiss);

    return () => {
      player.removeEventListener("complete", dismiss);
    };
  }, [player]);

  if (!hasChecked || !shouldPlay || isDismissed || prefersReducedMotion) {
    return null;
  }

  return (
    <div
      aria-hidden="true"
      className="pointer-events-none fixed inset-0 z-50"
      data-sources={FANFARE_SOURCES.join(",")}
      data-testid="lottie-fanfare"
    >
      {FANFARE_SOURCES.map((source) => (
        <DotLottieReact
          autoplay
          className="absolute inset-0 h-screen w-screen"
          dotLottieRefCallback={source === COMPLETE_SOURCE ? setPlayer : undefined}
          key={source}
          loop={false}
          src={source}
        />
      ))}
    </div>
  );
}
