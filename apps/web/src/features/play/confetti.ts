/**
 * 해설 화면에서 터뜨리는 컨페티.
 *
 * 색은 globals.css @theme 토큰에서 런타임에 읽는다 — 소스에 raw hex를 넣으면
 * check:design 게이트가 막고, 토큰이 바뀌어도 연출이 따라오지 않는다.
 */

const CONFETTI_COLOR_TOKENS = ["--color-primary", "--color-accent", "--color-ox-o"] as const;

function readTokenColors(): string[] {
  const styles = getComputedStyle(document.documentElement);

  return CONFETTI_COLOR_TOKENS.map((token) => styles.getPropertyValue(token).trim()).filter(
    (color) => color.length > 0,
  );
}

/**
 * 실패해도 절대 던지지 않는다 — 연출 때문에 해설 화면이 막히면 안 된다.
 * 토큰을 못 읽으면 하드코딩 색으로 때우지 않고 그냥 생략한다.
 */
export async function fireConfetti() {
  const colors = readTokenColors();
  if (colors.length === 0) {
    return;
  }

  try {
    // 사용자 이벤트/이펙트 안에서만 부른다 — 모듈 top-level이면 SSR에서 document에 닿는다.
    const { default: confetti } = await import("canvas-confetti");
    confetti({
      colors,
      disableForReducedMotion: true,
      origin: { x: 0.5, y: 0.3 },
      particleCount: 70,
      spread: 78,
      startVelocity: 34,
      ticks: 140,
    });
  } catch {
    /* 지연 로드 실패는 연출만 생략한다 */
  }
}
