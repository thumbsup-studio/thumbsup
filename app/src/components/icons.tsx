import type { ComponentProps } from "react";

type IconProps = Omit<ComponentProps<"svg">, "children">;

export function ChevronLeftIcon(props: IconProps) {
  return (
    <svg aria-hidden="true" fill="none" height={24} viewBox="0 0 24 24" width={24} {...props}>
      <path
        d="M15 6l-6 6 6 6"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
      />
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

/** 아틀라스 다크 빈 상태에 쓰는 "연결이 끊긴 노드" 장식 아이콘. */
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
