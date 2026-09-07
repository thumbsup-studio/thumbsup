import { Chip } from "@/components/ui/chip";
import type { JobStatus } from "@/features/authoring/types";

type Status = JobStatus["status"];

const LABEL: Record<Status, string> = {
  QUEUED: "대기",
  RUNNING: "실행 중",
  SUCCEEDED: "완료",
  FAILED: "실패",
};

const TONE: Record<Status, "neutral" | "primary" | "success" | "danger"> = {
  QUEUED: "neutral",
  RUNNING: "primary",
  SUCCEEDED: "success",
  FAILED: "danger",
};

export function JobStatusChip({ status }: { status: Status }) {
  return <Chip tone={TONE[status]}>{LABEL[status]}</Chip>;
}
