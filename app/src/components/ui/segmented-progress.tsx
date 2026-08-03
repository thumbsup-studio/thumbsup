/**
 * 문제 수만큼 칸을 나눠 보여주는 진행바.
 *
 * 단색 막대와 달리 "몇 문제 중 몇 번째"가 한눈에 보이고, 한 칸이 채워지는 순간이
 * 눈에 띄어 진행 자체가 보상으로 느껴진다(퀴즈·학습 앱의 공통 패턴).
 * 총 개수는 스텝마다 다르므로 호출자가 서버에서 받은 값을 그대로 넘긴다.
 */
export function SegmentedProgress({
  value,
  total,
  label = "진행률",
  hot = false,
}: {
  /** 채점을 마친 문제 수 */
  value: number;
  /** 이번 스텝의 전체 문제 수 */
  total: number;
  label?: string;
  /** 연속 정답이 이어지는 동안 true — 채워진 칸을 스트릭 색으로 바꾼다 */
  hot?: boolean;
}) {
  const safeTotal = Math.max(0, Math.trunc(total));
  const done = Math.min(safeTotal, Math.max(0, Math.trunc(value)));

  return (
    <div
      role="progressbar"
      aria-valuenow={done}
      aria-valuemin={0}
      aria-valuemax={safeTotal}
      aria-label={label}
      className="flex h-2 w-full gap-1"
    >
      {Array.from({ length: safeTotal }, (_, index) => (
        <span
          className={`h-full flex-1 rounded-chip transition-colors duration-300 ease-out ${
            index < done ? (hot ? "bg-accent" : "bg-primary") : "bg-border"
          }`}
          // biome-ignore lint/suspicious/noArrayIndexKey: 칸은 순서 자체가 정체성인 고정 길이 목록이다 — 삽입·재정렬·상태가 없다.
          key={index}
        />
      ))}
    </div>
  );
}
