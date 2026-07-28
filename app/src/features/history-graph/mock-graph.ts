import type { HistoryGraphResponse } from "./types";

export const mockHistoryGraph: HistoryGraphResponse = {
  nodes: [
    {
      id: "process",
      label: "프로세스",
      description:
        "실행 중인 프로그램의 인스턴스입니다. 운영체제는 프로세스마다 독립된 주소 공간과 실행 상태를 관리합니다.",
      learnedAt: "2026-07-08",
      category: "운영체제",
      relatedSteps: [{ stepOrder: 1, topic: "프로세스와 스레드" }],
      position: { x: 0, y: 0 },
    },
    {
      id: "thread",
      label: "스레드",
      description:
        "프로세스 안에서 실행되는 작업 흐름입니다. 같은 프로세스의 메모리를 공유하므로 전환 비용이 작지만 동기화가 중요합니다.",
      learnedAt: "2026-07-08",
      category: "운영체제",
      relatedSteps: [{ stepOrder: 1, topic: "프로세스와 스레드" }],
      position: { x: -92, y: 16 },
    },
    {
      id: "context-switch",
      label: "문맥 전환",
      description:
        "CPU가 실행 대상을 바꿀 때 레지스터, 프로그램 카운터 같은 실행 상태를 저장하고 복원하는 과정입니다.",
      learnedAt: "2026-07-09",
      category: "운영체제",
      relatedSteps: [{ stepOrder: 2, topic: "CPU 스케줄링" }],
      position: { x: 100, y: 28 },
    },
    {
      id: "scheduling",
      label: "스케줄링",
      description:
        "준비 큐에 있는 작업 중 어떤 것을 CPU에 올릴지 결정하는 정책입니다. 응답 시간과 처리량의 균형이 핵심입니다.",
      learnedAt: "2026-07-09",
      category: "운영체제",
      relatedSteps: [{ stepOrder: 2, topic: "CPU 스케줄링" }],
      position: { x: 136, y: 112 },
    },
    {
      id: "race-condition",
      label: "경쟁 상태",
      description:
        "여러 실행 흐름이 공유 자원에 동시에 접근해 실행 순서에 따라 결과가 달라지는 문제입니다.",
      learnedAt: "2026-07-10",
      category: "동시성",
      relatedSteps: [{ stepOrder: 3, topic: "동기화와 임계구역" }],
      position: { x: -134, y: 82 },
    },
    {
      id: "critical-section",
      label: "임계 구역",
      description:
        "공유 자원에 접근하는 코드 영역입니다. 동시에 하나의 실행 흐름만 들어가도록 보호해야 합니다.",
      learnedAt: "2026-07-10",
      category: "동시성",
      relatedSteps: [{ stepOrder: 3, topic: "동기화와 임계구역" }],
      position: { x: -72, y: 132 },
    },
    {
      id: "deadlock",
      label: "교착 상태",
      description: "둘 이상의 작업이 서로 가진 자원을 기다리며 더 이상 진행하지 못하는 상태입니다.",
      learnedAt: "2026-07-11",
      category: "동시성",
      relatedSteps: [{ stepOrder: 4, topic: "교착 상태" }],
      position: { x: 24, y: 130 },
    },
    {
      id: "paging",
      label: "페이징",
      description:
        "가상 주소 공간을 고정 크기 페이지로 나눠 물리 메모리 프레임에 매핑하는 메모리 관리 방식입니다.",
      learnedAt: "2026-07-12",
      category: "메모리",
      relatedSteps: [{ stepOrder: 9, topic: "메모리 관리 기초" }],
      position: { x: 58, y: -72 },
    },
    {
      id: "page-fault",
      label: "페이지 폴트",
      description:
        "접근하려는 페이지가 메모리에 없을 때 발생하는 예외입니다. 운영체제는 필요한 페이지를 적재한 뒤 실행을 재개합니다.",
      learnedAt: "2026-07-13",
      category: "메모리",
      relatedSteps: [{ stepOrder: 10, topic: "가상 메모리" }],
      position: { x: 94, y: -10 },
    },
  ],
  edges: [
    { source: "process", target: "thread" },
    { source: "process", target: "context-switch" },
    { source: "thread", target: "race-condition" },
    { source: "context-switch", target: "scheduling" },
    { source: "race-condition", target: "critical-section" },
    { source: "critical-section", target: "deadlock" },
    { source: "scheduling", target: "deadlock" },
    { source: "paging", target: "page-fault" },
    { source: "process", target: "paging" },
    { source: "deadlock", target: "page-fault" },
  ],
};

export async function getMockHistoryGraph(): Promise<HistoryGraphResponse> {
  return mockHistoryGraph;
}
