/**
 * 인라인 SVG 아이콘 (lucide 계열 path).
 * 색은 `currentColor`, 크기는 caller가 className(`size-5` 등)으로 지정 → 토큰/유틸리티만 사용.
 * components/ui 밖에 두어 스토리 요구(check:design)를 받지 않는다.
 */
import type { ComponentProps } from "react";

type IconProps = ComponentProps<"svg">;

/** 선(stroke) 계열 공통 svg */
function StrokeIcon({ children, ...props }: IconProps) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      {children}
    </svg>
  );
}

export function MailIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <rect width="20" height="16" x="2" y="4" rx="2" />
      <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
    </StrokeIcon>
  );
}

export function LockIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <rect width="18" height="11" x="3" y="11" rx="2" ry="2" />
      <path d="M7 11V7a5 5 0 0 1 10 0v4" />
    </StrokeIcon>
  );
}

export function EyeIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0" />
      <circle cx="12" cy="12" r="3" />
    </StrokeIcon>
  );
}

export function EyeOffIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <path d="M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49" />
      <path d="M14.084 14.158a3 3 0 0 1-4.242-4.242" />
      <path d="M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143" />
      <path d="m2 2 20 20" />
    </StrokeIcon>
  );
}

export function AlertCircleIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <circle cx="12" cy="12" r="10" />
      <line x1="12" x2="12" y1="8" y2="12" />
      <line x1="12" x2="12.01" y1="16" y2="16" />
    </StrokeIcon>
  );
}

export function ChevronLeftIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <path d="m15 18-6-6 6-6" />
    </StrokeIcon>
  );
}

export function CheckIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <path d="M20 6 9 17l-5-5" />
    </StrokeIcon>
  );
}

export function HelpCircleIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <circle cx="12" cy="12" r="10" />
      <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
      <path d="M12 17h.01" />
    </StrokeIcon>
  );
}

export function ArrowLeftIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <path d="M19 12H5" />
      <path d="m12 19-7-7 7-7" />
    </StrokeIcon>
  );
}

export function ArrowRightIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <path d="M5 12h14" />
      <path d="m12 5 7 7-7 7" />
    </StrokeIcon>
  );
}

export function RotateCcwIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
      <path d="M3 3v5h5" />
    </StrokeIcon>
  );
}

/** 회전 스피너 (버튼 로딩용). prefers-reduced-motion에서는 정지. */
export function SpinnerIcon({ className = "", ...props }: IconProps) {
  return (
    <StrokeIcon className={`motion-safe:animate-spin ${className}`} {...props}>
      <path d="M21 12a9 9 0 1 1-6.219-8.56" />
    </StrokeIcon>
  );
}

/** 솔리드 엄지척(앱 브랜드 마크) — 흰색 위 배경 대비로 채움. */
export function ThumbsUpIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" focusable="false" {...props}>
      <path d="M15 5.88 14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2h2.76a2 2 0 0 0 1.79-1.11L12 2a3.13 3.13 0 0 1 3 3.88Z" />
    </svg>
  );
}

export function ShareIcon(props: IconProps) {
  return (
    <svg aria-hidden="true" fill="none" height={24} viewBox="0 0 24 24" width={24} {...props}>
      <path
        d="M12 16V4m0 0L7 9m5-5l5 5M5 14v4a2 2 0 002 2h10a2 2 0 002-2v-4"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
      />
    </svg>
  );
}

export function SearchIcon(props: IconProps) {
  return (
    <svg aria-hidden="true" fill="none" height={20} viewBox="0 0 24 24" width={20} {...props}>
      <circle cx={11} cy={11} r={7} stroke="currentColor" strokeWidth={2} />
      <path d="M21 21l-4.3-4.3" stroke="currentColor" strokeLinecap="round" strokeWidth={2} />
    </svg>
  );
}

export function PlayIcon(props: IconProps) {
  return (
    <svg
      aria-hidden="true"
      fill="currentColor"
      height={16}
      viewBox="0 0 24 24"
      width={16}
      {...props}
    >
      <path d="M6 4l14 8-14 8V4z" />
    </svg>
  );
}

export function DisconnectedNodesIcon(props: IconProps) {
  return (
    <svg aria-hidden="true" fill="none" height={56} viewBox="0 0 56 56" width={56} {...props}>
      <path
        d="M16 15l9 13M40 15l-9 13"
        stroke="currentColor"
        strokeLinecap="round"
        strokeWidth={1.5}
      />
      <circle
        className="fill-graph-surface"
        cx={12}
        cy={12}
        r={5}
        stroke="currentColor"
        strokeWidth={1.5}
      />
      <circle
        className="fill-graph-surface"
        cx={44}
        cy={12}
        r={5}
        stroke="currentColor"
        strokeWidth={1.5}
      />
      <circle className="fill-graph-learning" cx={28} cy={34} r={8} />
    </svg>
  );
}
