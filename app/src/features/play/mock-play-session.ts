import type { PlaySession } from "@/features/play/types";

export const mockPlaySession: PlaySession = {
  id: "mock-os-process-thread",
  courseTitle: "운영체제",
  unitTitle: "프로세스와 스레드",
  questions: [
    {
      id: "q-01-process-space",
      kind: "ox",
      difficulty: "low",
      prompt: "프로세스는 운영체제로부터 독립된 메모리 공간을 할당받아 실행된다.",
      answer: true,
      explanation: "프로세스는 코드, 데이터, 힙, 스택 등 독립된 주소 공간을 가진 실행 단위입니다.",
      insight: {
        summary: [
          "프로세스는 실행 중인 프로그램의 독립 실행 단위입니다.",
          "운영체제는 프로세스마다 별도 주소 공간과 자원을 관리합니다.",
          "스레드는 이 프로세스 안에서 실행 흐름을 나눕니다.",
        ],
        wrongReason:
          "프로세스를 단순한 코드 파일로만 보면 운영체제가 실행 중 자원을 분리해 관리한다는 점을 놓치기 쉽습니다.",
        codeExample: {
          language: "pseudo",
          source: `process = os.spawn("browser-tab")
process.memory = isolated_address_space`,
          description:
            "운영체제는 프로세스를 만들 때 독립된 주소 공간을 붙여 실행 중인 단위로 관리합니다.",
        },
        usageExample:
          "브라우저 탭 하나가 별도 프로세스로 실행되면 한 탭의 오류가 다른 탭으로 번지기 어렵습니다.",
        keywords: [
          {
            term: "프로세스",
            description: "운영체제가 자원을 독립적으로 관리하는 실행 단위입니다.",
          },
          {
            term: "운영체제",
            description: "CPU, 메모리, 파일 같은 컴퓨터 자원을 관리하는 시스템 소프트웨어입니다.",
          },
          {
            term: "스레드",
            description: "프로세스 안에서 나뉘는 실행 흐름입니다.",
          },
        ],
        referenceLabel: "OS process model",
      },
      followUpQuestions: [
        {
          followUpQuestionId: 1,
          content: "독립된 메모리 공간을 쓴다면, 프로세스끼리는 어떻게 데이터를 주고받을까?",
          isPrimary: true,
        },
      ],
    },
    {
      id: "q-02-thread-memory",
      kind: "ox",
      difficulty: "low",
      prompt: "같은 프로세스 안의 스레드들은 코드와 힙 영역을 공유할 수 없다.",
      answer: false,
      explanation:
        "스레드는 같은 프로세스 안에서 코드, 데이터, 힙을 공유하고 각자 스택을 가집니다.",
      insight: {
        summary: [
          "스레드는 같은 프로세스의 주소 공간을 공유합니다.",
          "공유 영역이 있기 때문에 통신은 가볍지만 동시성 문제가 생길 수 있습니다.",
          "각 스레드는 독립적인 호출 흐름을 위해 자신의 스택을 가집니다.",
        ],
        wrongReason:
          "스레드를 작은 프로세스처럼 생각하면 코드와 힙까지 분리된다고 착각할 수 있습니다.",
        codeExample: {
          language: "pseudo",
          source: `threadA.cache = shared_heap.cache
threadB.cache = shared_heap.cache`,
          description:
            "같은 프로세스의 스레드는 힙과 데이터를 공유하므로 공통 캐시에 접근할 수 있습니다.",
        },
        usageExample:
          "웹 서버가 요청마다 스레드를 나누면 공통 캐시를 공유하면서도 요청 처리를 병렬화할 수 있습니다.",
        keywords: [
          {
            term: "스레드",
            description: "프로세스 내부에서 독립적으로 스케줄링되는 실행 흐름입니다.",
          },
          {
            term: "힙",
            description: "동적으로 만든 객체와 공유 데이터가 주로 놓이는 메모리 영역입니다.",
          },
          {
            term: "스택",
            description: "함수 호출과 지역 변수처럼 각 실행 흐름의 상태를 담는 메모리 영역입니다.",
          },
        ],
        referenceLabel: "Thread memory layout",
      },
      followUpQuestions: [
        {
          followUpQuestionId: 2,
          content: "스레드가 힙을 공유한다면, 여러 스레드가 같은 변수를 동시에 바꾸면 어떻게 될까?",
          isPrimary: true,
        },
      ],
    },
    {
      id: "q-03-race-condition",
      kind: "multiple-choice",
      difficulty: "medium",
      prompt: "다음 코드에서 여러 스레드가 동시에 실행할 때 가장 직접적으로 발생할 수 있는 문제는?",
      code: {
        language: "ts",
        source: `let count = 0;

function increase() {
  count = count + 1;
}`,
      },
      options: [
        { id: "a", label: "데드락" },
        { id: "b", label: "경쟁 상태" },
        { id: "c", label: "기아 상태" },
        { id: "d", label: "페이지 폴트" },
      ],
      answerId: "b",
      explanation:
        "`count = count + 1`은 읽기와 쓰기가 분리되어 있어 동시 실행 시 값이 유실될 수 있습니다.",
      insight: {
        summary: [
          "경쟁 상태는 실행 순서에 따라 결과가 달라지는 동시성 문제입니다.",
          "읽기, 계산, 쓰기가 원자적으로 묶이지 않으면 값이 유실될 수 있습니다.",
          "락이나 원자 연산으로 공유 상태 접근을 보호해야 합니다.",
        ],
        wrongReason:
          "한 줄의 증가식이라도 실제로는 읽기, 계산, 쓰기 단계로 나뉘기 때문에 동시에 실행되면 안전하지 않습니다.",
        codeExample: {
          language: "ts",
          source: `mutex.lock();
try {
  count = count + 1;
} finally {
  mutex.unlock();
}`,
          description:
            "락이나 원자 연산으로 공유 상태 접근을 한 번에 하나의 흐름만 실행하게 보호합니다.",
        },
        usageExample:
          "두 스레드가 동시에 count 값을 0으로 읽고 각각 1을 쓰면 실제 증가 횟수는 2번이어도 결과는 1이 됩니다.",
        keywords: [
          {
            term: "경쟁 상태",
            description: "동시 실행 순서에 따라 결과가 달라지는 버그입니다.",
          },
          {
            term: "원자 연산",
            description: "중간에 끼어들 수 없도록 하나의 단위처럼 처리되는 연산입니다.",
          },
          {
            term: "락",
            description: "공유 자원에 동시에 접근하지 못하게 막는 동기화 장치입니다.",
          },
        ],
        referenceLabel: "Race condition",
      },
      followUpQuestions: [
        {
          followUpQuestionId: 3,
          content: "경쟁 상태를 막으려고 락을 여러 개 걸면, 이번엔 어떤 문제가 생길까?",
          isPrimary: true,
        },
      ],
    },
    {
      id: "q-04-context-switch",
      kind: "multiple-choice",
      difficulty: "medium",
      prompt: "컨텍스트 스위칭이 자주 발생할 때 성능이 떨어지는 가장 큰 이유는?",
      options: [
        { id: "a", label: "CPU가 프로세스 상태를 저장하고 복원하는 부가 작업을 반복하기 때문" },
        { id: "b", label: "프로그램의 코드 영역이 항상 삭제되기 때문" },
        { id: "c", label: "스레드가 파일 시스템 접근 권한을 잃기 때문" },
        { id: "d", label: "운영체제가 네트워크 연결을 모두 초기화하기 때문" },
      ],
      answerId: "a",
      explanation:
        "컨텍스트 스위칭은 실행 문맥 저장과 복원 비용을 만들며 캐시 효율도 떨어뜨릴 수 있습니다.",
      insight: {
        summary: [
          "컨텍스트 스위칭은 CPU가 실행 대상을 바꿀 때 필요한 문맥 교체입니다.",
          "레지스터와 실행 위치를 저장하고 다음 작업의 상태를 복원합니다.",
          "너무 자주 발생하면 실제 작업보다 교체 비용이 커질 수 있습니다.",
        ],
        wrongReason:
          "컨텍스트 스위칭은 단순히 순서만 바꾸는 일이 아니라 CPU 상태 저장과 복원 비용을 동반합니다.",
        codeExample: {
          language: "pseudo",
          source: `save(current.registers)
load(next.registers)
run(next)`,
          description:
            "운영체제는 현재 실행 상태를 저장하고 다음 실행 상태를 복원한 뒤 CPU를 넘깁니다.",
        },
        usageExample:
          "짧은 작업을 지나치게 많은 스레드로 쪼개면 CPU가 계산보다 스레드 전환에 시간을 더 쓸 수 있습니다.",
        keywords: [
          {
            term: "컨텍스트 스위칭",
            description:
              "CPU가 실행할 작업을 바꾸며 이전 상태를 저장하고 다음 상태를 복원하는 과정입니다.",
          },
          {
            term: "레지스터",
            description: "CPU가 바로 계산에 쓰는 아주 빠른 임시 저장 공간입니다.",
          },
          {
            term: "스레드",
            description: "CPU 스케줄링의 대상이 될 수 있는 실행 흐름입니다.",
          },
        ],
        referenceLabel: "Context switching",
      },
      followUpQuestions: [],
    },
    {
      id: "q-05-critical-section",
      kind: "keyword-blank",
      difficulty: "high",
      prompt: "공유 자원에 동시에 접근하면 안 되는 코드 영역을 무엇이라고 부를까요?",
      blankLabel: "핵심 키워드",
      code: {
        language: "pseudo",
        before: `lock.acquire()
try:
  // `,
        after: `에서 공유 자원을 수정한다
finally:
  lock.release()`,
      },
      acceptedAnswers: ["임계 구역", "critical section", "critical-section", "criticalsection"],
      explanation:
        "임계 구역은 공유 자원 접근을 보호해야 하는 코드 영역이며 락으로 상호 배제를 구현합니다.",
      insight: {
        summary: [
          "임계 구역은 동시에 실행되면 안 되는 공유 자원 접근 코드입니다.",
          "상호 배제를 보장해야 데이터가 깨지지 않습니다.",
          "락의 범위는 필요한 만큼만 좁게 잡는 것이 좋습니다.",
        ],
        wrongReason:
          "공유 자원을 다루는 코드 중에서도 동시에 들어오면 결과가 깨지는 구간을 따로 식별해야 합니다.",
        codeExample: {
          language: "pseudo",
          source: `lock.acquire()
try:
  balance = balance - payment
finally:
  lock.release()`,
          description: "공유 자원을 수정하는 코드만 락으로 감싸 임계 구역을 보호합니다.",
        },
        usageExample:
          "계좌 잔액을 읽고 차감한 뒤 저장하는 구간은 동시에 실행되면 잔액 오류가 생길 수 있어 임계 구역으로 보호합니다.",
        keywords: [
          {
            term: "임계 구역",
            description: "동시에 실행되면 안 되는 공유 자원 접근 코드 영역입니다.",
          },
          {
            term: "상호 배제",
            description: "한 번에 하나의 실행 흐름만 공유 자원에 접근하게 하는 성질입니다.",
          },
          {
            term: "락",
            description: "상호 배제를 구현할 때 쓰는 잠금 장치입니다.",
          },
        ],
        referenceLabel: "Critical section",
      },
      followUpQuestions: [],
    },
  ],
};
