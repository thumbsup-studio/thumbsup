import type { KeyboardEvent } from "react";

export type MasteryLevel = "master" | "learning" | "unlearned";

export const MASTERY_LABEL: Record<MasteryLevel, string> = {
  master: "마스터",
  learning: "학습중",
  unlearned: "미학습",
};

/** 노드 글로우 SVG 필터 id. 필터 정의는 상위 svg의 <defs>(AtlasCanvas)에 있다. */
export const GRAPH_NODE_GLOW_ID = "graph-node-glow";

type GlyphColor = { stroke: string; fill: string };

// 노드 필(pill) 안에서 쓰는 색 — 필 배경색과 대비되도록 맞춘다(마스터=진한 네이비, 학습중=흰색, 미학습=연한 회색).
const IN_PILL_COLOR: Record<MasteryLevel, GlyphColor> = {
  master: { stroke: "stroke-graph-bg", fill: "fill-graph-bg" },
  learning: { stroke: "stroke-graph-fg", fill: "fill-graph-fg" },
  unlearned: { stroke: "stroke-graph-fg-muted", fill: "fill-graph-fg-muted" },
};

// 범례 등 필 밖에서 단독으로 쓰는 색 — 상태를 색 자체로 나타낸다.
const STANDALONE_COLOR: Record<MasteryLevel, GlyphColor> = {
  master: { stroke: "stroke-graph-master", fill: "fill-graph-master" },
  learning: { stroke: "stroke-graph-learning", fill: "fill-graph-learning" },
  unlearned: { stroke: "stroke-graph-unlearned", fill: "fill-graph-unlearned" },
};

const PILL_FILL: Record<MasteryLevel, string> = {
  master: "fill-graph-master",
  learning: "fill-graph-learning",
  unlearned: "fill-graph-surface",
};

const PILL_TEXT: Record<MasteryLevel, string> = {
  master: "fill-graph-bg",
  learning: "fill-graph-fg",
  unlearned: "fill-graph-fg-muted",
};

// 숙련도는 색만이 아니라 아이콘으로도 구분한다: 마스터=체크, 학습중=반원, 미학습=점선 원.
function MasteryGlyphCore({
  mastery,
  cx,
  cy,
  r,
  color,
  masterHasRing,
}: {
  mastery: MasteryLevel;
  cx: number;
  cy: number;
  r: number;
  color: GlyphColor;
  masterHasRing: boolean;
}) {
  if (mastery === "master") {
    const check = (
      <path
        className={`fill-none ${color.stroke}`}
        d={`M ${cx - r * 0.5} ${cy} L ${cx - r * 0.05} ${cy + r * 0.45} L ${cx + r * 0.55} ${cy - r * 0.5}`}
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.6}
      />
    );
    if (!masterHasRing) {
      return check;
    }
    return (
      <>
        <circle className={`fill-none ${color.stroke}`} cx={cx} cy={cy} r={r} strokeWidth={1.4} />
        {check}
      </>
    );
  }

  if (mastery === "learning") {
    return (
      <>
        <circle className={`fill-none ${color.stroke}`} cx={cx} cy={cy} r={r} strokeWidth={1.4} />
        <path className={color.fill} d={`M ${cx} ${cy - r} A ${r} ${r} 0 0 0 ${cx} ${cy + r} Z`} />
      </>
    );
  }

  return (
    <circle
      className={`fill-none ${color.stroke}`}
      cx={cx}
      cy={cy}
      r={r}
      strokeDasharray="2 2"
      strokeWidth={1.4}
    />
  );
}

/** GraphNode 필 안에 임베드하는 형태(자체 svg 없음). */
export function MasteryGlyph({
  mastery,
  cx,
  cy,
  r,
}: {
  mastery: MasteryLevel;
  cx: number;
  cy: number;
  r: number;
}) {
  return (
    <MasteryGlyphCore
      color={IN_PILL_COLOR[mastery]}
      cx={cx}
      cy={cy}
      mastery={mastery}
      masterHasRing={false}
      r={r}
    />
  );
}

/** 범례처럼 단독으로 쓰는 아이콘(자체 svg 포함). */
export function MasteryIcon({
  mastery,
  size = 16,
  className = "",
}: {
  mastery: MasteryLevel;
  size?: number;
  className?: string;
}) {
  const r = size / 2 - 1.5;
  const c = size / 2;
  return (
    <svg
      aria-hidden="true"
      className={className}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
      width={size}
    >
      <MasteryGlyphCore
        color={STANDALONE_COLOR[mastery]}
        cx={c}
        cy={c}
        mastery={mastery}
        masterHasRing
        r={r}
      />
    </svg>
  );
}

const PILL_HEIGHT = 40;
const ICON_RADIUS = 7;
const PADDING_X = 14;
const ICON_GAP = 6;
const ASCII_CHAR_WIDTH = 8;
const WIDE_CHAR_WIDTH = 14; // CJK(한글 등)는 text-sm에서 대략 전각 폭

// 한글 라벨은 ASCII보다 넓어 length*고정폭으로는 필이 좁게 잡혀 텍스트가 넘친다.
// 런타임 getBBox는 SSR에서 못 쓰므로 문자 종류별 근사 폭으로 추정한다.
// 한글 자모·가나·CJK·전각 영역을 전각 폭으로 취급.
const WIDE_CHAR = /[ᄀ-ᇿ぀-ヿ㐀-鿿가-힯＀-￯]/;
function estimateTextWidth(text: string): number {
  let width = 0;
  for (const char of text) {
    width += WIDE_CHAR.test(char) ? WIDE_CHAR_WIDTH : ASCII_CHAR_WIDTH;
  }
  return width;
}

export type GraphNodeProps = {
  id: string;
  label: string;
  mastery: MasteryLevel;
  /** SVG viewBox 좌표계에서 노드 중심 x */
  x: number;
  /** SVG viewBox 좌표계에서 노드 중심 y */
  y: number;
  selected?: boolean;
  onSelect?: (id: string) => void;
};

export function GraphNode({
  id,
  label,
  mastery,
  x,
  y,
  selected = false,
  onSelect,
}: GraphNodeProps) {
  const width = Math.max(64, estimateTextWidth(label) + ICON_RADIUS * 2 + PADDING_X * 2 + ICON_GAP);
  const left = x - width / 2;
  const top = y - PILL_HEIGHT / 2;
  const iconCx = left + PADDING_X + ICON_RADIUS;
  const textX = iconCx + ICON_RADIUS + ICON_GAP;

  function handleKeyDown(event: KeyboardEvent<SVGGElement>) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      onSelect?.(id);
    }
  }

  return (
    // biome-ignore lint/a11y/useSemanticElements: <button>은 SVG 콘텐츠 모델에 못 들어감 — <g role="button">이 표준 SVG 접근성 패턴
    <g
      aria-label={`${label}, 숙련도 ${MASTERY_LABEL[mastery]}`}
      aria-pressed={selected}
      className="cursor-pointer"
      onClick={() => onSelect?.(id)}
      onKeyDown={handleKeyDown}
      role="button"
      tabIndex={0}
    >
      <rect
        className={`${PILL_FILL[mastery]} ${selected ? "stroke-graph-fg" : "stroke-transparent"}`}
        filter={mastery === "unlearned" ? undefined : `url(#${GRAPH_NODE_GLOW_ID})`}
        height={PILL_HEIGHT}
        rx={PILL_HEIGHT / 2}
        strokeWidth={selected ? 3 : 0}
        width={width}
        x={left}
        y={top}
      />
      <MasteryGlyph cx={iconCx} cy={y} mastery={mastery} r={ICON_RADIUS} />
      <text
        className={`${PILL_TEXT[mastery]} text-sm font-semibold`}
        dominantBaseline="middle"
        x={textX}
        y={y}
      >
        {label}
      </text>
    </g>
  );
}
