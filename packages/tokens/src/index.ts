export const tokens = {
  color: {
    primary: "#2f63ff",
    "primary-fg": "#ffffff",
    accent: "#f5923e",
    badge: "#ffce31",
    "badge-fg": "#4a3200",
    "ox-o": "#3fc27c",
    "ox-x": "#ee6868",
    success: "#1f7a4d",
    danger: "#dc2626",
    warning: "#f59e0b",
    info: "#4f7096",
    bg: "#f4f7fb",
    surface: "#ffffff",
    "surface-muted": "#eef2f8",
    ink: "#020617",
    "ink-muted": "#5b6b81",
    border: "#e2e8f0",
    "graph-bg": "#0a0f1f",
    "graph-surface": "#1d273f",
    "graph-master": "#34c88a",
    "graph-learning": "#2f63ff",
    "graph-unlearned": "#8a97b5",
    "graph-edge": "#4b5a80",
    "graph-fg": "#ffffff",
    "graph-fg-muted": "#b8c2da",
    "character-fur": "#c99b72",
    "character-muzzle": "#f0e1c8",
    "character-nose": "#3b2a20",
    "character-blush": "#f3b9ac",
  },
  radius: { card: "2rem", control: "1rem", chip: "9999px" },
  shadow: {
    card: "0 24px 60px rgba(15, 23, 42, 0.1)",
    hero: "0 24px 48px rgba(47, 99, 255, 0.24)",
    choice: "0 4px 0 var(--color-border)",
    "choice-selected": "0 4px 0 var(--color-primary)",
  },
  font: {
    sans: "var(--font-pretendard), ui-sans-serif, system-ui, sans-serif",
    mono: "var(--font-geist-mono), ui-monospace, monospace",
  },
  animate: {
    "sheet-rise": "sheet-rise 0.24s cubic-bezier(0.4, 0, 0.2, 1)",
    "overlay-fade": "overlay-fade 0.18s ease",
    "celebration-pop": "celebration-pop 0.42s cubic-bezier(0.34, 1.56, 0.64, 1)",
    "combo-bounce": "combo-bounce 0.5s cubic-bezier(0.34, 1.56, 0.64, 1)",
    "rise-in": "rise-in 0.32s cubic-bezier(0.22, 1, 0.36, 1) both",
    "choice-in": "choice-in 0.34s cubic-bezier(0.22, 1, 0.36, 1) both",
    "check-draw": "check-draw 0.4s cubic-bezier(0.65, 0, 0.35, 1) both",
  },
} as const;

export const keyframes = {
  "sheet-rise": { from: { transform: "translateY(100%)" }, to: { transform: "translateY(0)" } },
  "overlay-fade": { from: { opacity: "0" }, to: { opacity: "1" } },
  "celebration-pop": {
    from: { opacity: "0", transform: "scale(0.72)" },
    to: { opacity: "1", transform: "scale(1)" },
  },
  "rise-in": {
    from: { opacity: "0", transform: "translateY(0.75rem)" },
    to: { opacity: "1", transform: "translateY(0)" },
  },
  "choice-in": {
    from: { opacity: "0", transform: "translateY(0.5rem) scale(0.98)" },
    to: { opacity: "1", transform: "translateY(0) scale(1)" },
  },
  "check-draw": { from: { "stroke-dashoffset": "100" }, to: { "stroke-dashoffset": "0" } },
  "combo-bounce": {
    "0%": { opacity: "0", transform: "translateY(0.5rem) scale(0.8)" },
    "60%": { opacity: "1", transform: "translateY(-0.25rem) scale(1.08)" },
    "100%": { opacity: "1", transform: "translateY(0) scale(1)" },
  },
} as const;

export type ThumbsupTokens = typeof tokens;
