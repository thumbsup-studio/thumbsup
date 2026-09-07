import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { DraftDetailScreen } from "@/features/authoring/components/draft-detail-screen";
import type { DraftDetail } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { getDraftMock, reviewDraftMock, approveDraftMock, mockRouter } = vi.hoisted(() => ({
  getDraftMock: vi.fn(),
  reviewDraftMock: vi.fn(),
  approveDraftMock: vi.fn(),
  // useRouter()가 매 렌더 새 객체를 반환하면 router를 deps로 둔 useCallback이 매 렌더 재생성돼
  // useEffect가 무한 재실행된다(T4 사고 재발 방지 — 안정된 단일 참조를 반환한다).
  mockRouter: { push: vi.fn(), replace: vi.fn() },
}));

vi.mock("@/features/authoring/api", () => ({
  getDraft: getDraftMock,
  reviewDraft: reviewDraftMock,
  approveDraft: approveDraftMock,
}));
vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));

function renderScreen() {
  render(
    <AppToastProvider>
      <DraftDetailScreen draftId={5} />
    </AppToastProvider>,
  );
}

const BASE_DRAFT: DraftDetail = {
  draftId: 5,
  origin: "NEW",
  status: "DRAFT",
  topic: "운영체제",
  sourceQuizId: null,
  revisionCount: 2,
  updatedAt: "2026-07-14T00:00:00Z",
  payload: {
    quizzes: [
      {
        type: "OX",
        difficulty: "EASY",
        questionText: "프로세스는 독립된 자원을 갖는다.",
        hint: "특권 명령을 어떤 실행 모드에서 다루는지 떠올려 보세요.",
        codeSnippet: null,
        explanationSummary: "프로세스는 자원을 독립적으로 관리한다.",
        explanationExample: null,
        wrongAnswerExplanation: "스레드와 혼동하지 말 것.",
        correctAnswer: "O",
        choices: null,
        answerKeywords: null,
        followUpQuestions: null,
        derivedConcepts: null,
        keywords: null,
      },
      {
        type: "MULTIPLE_CHOICE",
        difficulty: "MEDIUM",
        questionText: "다음 중 옳은 것은?",
        hint: "선택지별 핵심 조건을 운영체제의 보호 경계와 비교해 보세요.",
        codeSnippet: null,
        explanationSummary: "정답은 B다.",
        explanationExample: null,
        wrongAnswerExplanation: "A는 오답이다.",
        correctAnswer: null,
        choices: [
          { content: "A 선지", isCorrect: false },
          { content: "B 선지", isCorrect: true },
        ],
        answerKeywords: null,
        followUpQuestions: null,
        derivedConcepts: null,
        keywords: null,
      },
    ],
  },
  revisions: [
    {
      revisionNo: 1,
      reviewSummary: "선지 순서 수정",
      reviewedBy: 2,
      jobId: 10,
      createdAt: "2026-07-14T01:00:00Z",
    },
    {
      revisionNo: 2,
      reviewSummary: "설명 보강",
      reviewedBy: 3,
      jobId: 11,
      createdAt: "2026-07-14T02:00:00Z",
    },
  ],
  createdBy: 1,
  approvedBy: null,
  approvedAt: null,
};

// payload 전 필드(정답류·해설 3종·키워드 사전·파생 개념·꼬리질문)가 화면에 실제로 그려지는지
// 검증하기 위한 전용 draft — BASE_DRAFT와 분리해 기존 케이스에 영향을 주지 않는다.
const RICH_DRAFT: DraftDetail = {
  ...BASE_DRAFT,
  payload: {
    quizzes: [
      {
        type: "KEYWORD_BLANK",
        difficulty: "HARD",
        questionText:
          "[[LIFO]] 구조를 쓰는 자료구조는 스택이며 접근 시간복잡도는 [[CONST_TIME]]이다.",
        hint: "삽입과 삭제가 일어나는 끝의 위치와 항목 순서를 추적해 보세요.",
        codeSnippet: null,
        explanationSummary: "스택은 후입선출 구조로 동작한다.",
        explanationExample: "함수 호출 스택이 대표적인 실무 예시다.",
        wrongAnswerExplanation: "큐(FIFO)와 혼동하지 않아야 한다.",
        correctAnswer: null,
        choices: null,
        answerKeywords: [
          ["중위", "중위 순회", "inorder"],
          ["O(n)", "Θ(n)"],
        ],
        followUpQuestions: [
          {
            content: "스택과 큐의 가장 큰 차이는 무엇인가요?",
            isPrimary: true,
            difficulty: "EASY",
            oneLineAnswer: "삽입/삭제되는 순서가 서로 반대다.",
            blocks: [{ label: "핵심 정리", content: "스택은 LIFO, 큐는 FIFO 구조다." }],
            keywords: [{ keyword: "FIFO", description: "선입선출 구조" }],
          },
        ],
        derivedConcepts: ["재귀", "백트래킹"],
        keywords: [{ keyword: "LIFO", description: "후입선출 구조" }],
      },
    ],
  },
};

const legacyQuizWithoutHint = { ...BASE_DRAFT.payload.quizzes[0] };
delete legacyQuizWithoutHint.hint;
const LEGACY_DRAFT_WITHOUT_HINT: DraftDetail = {
  ...BASE_DRAFT,
  payload: { quizzes: [legacyQuizWithoutHint] },
};

const STEP_BRIEFING_DRAFT: DraftDetail = {
  ...BASE_DRAFT,
  origin: "OUTLINE_STEP",
  payload: {
    schemaVersion: 2,
    briefing: {
      summary: "프로세스와 스레드의 실행 단위 차이를 정리합니다.",
      blocks: [
        {
          type: "CONCEPT",
          heading: "자원 소유 단위",
          content: "프로세스는 실행에 필요한 자원을 독립적으로 관리합니다.",
        },
        {
          type: "CAUTION",
          heading: "실행 흐름과 혼동하지 않기",
          content: "스레드는 프로세스 내부에서 자원을 공유하는 실행 흐름입니다.",
        },
      ],
    },
    quizzes: BASE_DRAFT.payload.quizzes,
  },
};

beforeEach(() => {
  getDraftMock.mockReset();
  reviewDraftMock.mockReset();
  approveDraftMock.mockReset();
  mockRouter.push.mockReset();
  mockRouter.replace.mockReset();
});

describe("DraftDetailScreen", () => {
  it("스텝 브리핑을 문제 목록보다 먼저 순서대로 보여준다", async () => {
    getDraftMock.mockResolvedValue(STEP_BRIEFING_DRAFT);

    renderScreen();

    const summary = await screen.findByText("프로세스와 스레드의 실행 단위 차이를 정리합니다.");
    const firstQuestion = screen.getByText("프로세스는 독립된 자원을 갖는다.");
    expect(summary.compareDocumentPosition(firstQuestion) & Node.DOCUMENT_POSITION_FOLLOWING).toBe(
      Node.DOCUMENT_POSITION_FOLLOWING,
    );
    expect(screen.getByText("자원 소유 단위")).toBeInTheDocument();
    expect(screen.getByText("실행 흐름과 혼동하지 않기")).toBeInTheDocument();
  });

  it("브리핑이 없는 구형 스텝 초안은 재생성 안내를 명시한다", async () => {
    getDraftMock.mockResolvedValue({ ...BASE_DRAFT, origin: "OUTLINE_STEP" });

    renderScreen();

    expect(
      await screen.findByText(
        "브리핑이 없는 구형 초안이에요. 발행하려면 문제와 브리핑을 새로 생성해 주세요.",
      ),
    ).toBeInTheDocument();
  });

  it("payload.quizzes를 슬롯 순서대로 렌더한다(칩·질문·MC 정답 표시·해설 요약)", async () => {
    getDraftMock.mockResolvedValue(BASE_DRAFT);

    renderScreen();

    expect(await screen.findByText("프로세스는 독립된 자원을 갖는다.")).toBeInTheDocument();
    expect(screen.getByText("다음 중 옳은 것은?")).toBeInTheDocument();
    expect(screen.getByText(/B 선지/)).toBeInTheDocument();
    expect(screen.getByText(/정답은 B다\./)).toBeInTheDocument();
    expect(
      screen.getByText("특권 명령을 어떤 실행 모드에서 다루는지 떠올려 보세요."),
    ).toBeInTheDocument();
    expect(
      screen.getByText("선택지별 핵심 조건을 운영체제의 보호 경계와 비교해 보세요."),
    ).toBeInTheDocument();
    // 오답 선지엔 정답 표시가 없어야 한다
    expect(screen.getByText("A 선지")).toBeInTheDocument();
  });

  it("OX 슬롯의 correctAnswer(정답)가 화면에 보인다", async () => {
    getDraftMock.mockResolvedValue(BASE_DRAFT);

    renderScreen();

    await screen.findByText("프로세스는 독립된 자원을 갖는다.");
    // choices가 null인 OX 문제는 이 정답 표시가 유일한 정답 단서다 — 검수자가 O/X를 판단할 근거.
    expect(screen.getByText(/정답:\s*O/)).toBeInTheDocument();
  });

  it("legacy draft에 hint 키가 없으면 재검토 안내를 보여준다", async () => {
    getDraftMock.mockResolvedValue(LEGACY_DRAFT_WITHOUT_HINT);

    renderScreen();

    expect(
      await screen.findByText("힌트가 아직 생성되지 않았습니다. 재검토 후 승인하세요."),
    ).toBeInTheDocument();
  });

  it("KEYWORD_BLANK 슬롯의 answerKeywords가 빈칸별로 보인다(동의어는 같은 그룹)", async () => {
    getDraftMock.mockResolvedValue(RICH_DRAFT);

    renderScreen();

    await screen.findByText(/구조를 쓰는 자료구조는 스택이며/);
    // [[마커]]는 하이라이트로 변환하지 않고 원문 그대로 노출돼야 한다(검수자가 마커 규칙 위반을 육안 확인).
    expect(screen.getByText(/\[\[LIFO\]\]/)).toBeInTheDocument();
    expect(screen.getByText(/빈칸 1:.*중위.*중위 순회.*inorder/)).toBeInTheDocument();
    expect(screen.getByText(/빈칸 2:.*O\(n\).*Θ\(n\)/)).toBeInTheDocument();
  });

  it("explanationExample·wrongAnswerExplanation이 라벨과 함께 보인다", async () => {
    getDraftMock.mockResolvedValue(RICH_DRAFT);

    renderScreen();

    await screen.findByText(/구조를 쓰는 자료구조는 스택이며/);
    expect(screen.getByText("실무 예시")).toBeInTheDocument();
    expect(screen.getByText("함수 호출 스택이 대표적인 실무 예시다.")).toBeInTheDocument();
    expect(screen.getByText("오답 해설")).toBeInTheDocument();
    expect(screen.getByText("큐(FIFO)와 혼동하지 않아야 한다.")).toBeInTheDocument();
  });

  it("explanationExample이 null이면 '실무 예시' 라벨 없이도 깨지지 않는다", async () => {
    getDraftMock.mockResolvedValue(BASE_DRAFT);

    renderScreen();

    await screen.findByText("프로세스는 독립된 자원을 갖는다.");
    expect(screen.queryByText("실무 예시")).not.toBeInTheDocument();
    expect(screen.getByText("스레드와 혼동하지 말 것.")).toBeInTheDocument();
  });

  it("keywords 사전(용어+설명)이 보인다", async () => {
    getDraftMock.mockResolvedValue(RICH_DRAFT);

    renderScreen();

    await screen.findByText(/구조를 쓰는 자료구조는 스택이며/);
    expect(screen.getByText("LIFO")).toBeInTheDocument();
    expect(screen.getByText("후입선출 구조")).toBeInTheDocument();
  });

  it("derivedConcepts가 칩으로 보인다", async () => {
    getDraftMock.mockResolvedValue(RICH_DRAFT);

    renderScreen();

    await screen.findByText(/구조를 쓰는 자료구조는 스택이며/);
    expect(screen.getByText("재귀")).toBeInTheDocument();
    expect(screen.getByText("백트래킹")).toBeInTheDocument();
  });

  it("followUpQuestions의 oneLineAnswer·blocks가 접이식(details) 안에 렌더된다", async () => {
    getDraftMock.mockResolvedValue(RICH_DRAFT);

    renderScreen();

    await screen.findByText(/구조를 쓰는 자료구조는 스택이며/);
    expect(screen.getByText("스택과 큐의 가장 큰 차이는 무엇인가요?")).toBeInTheDocument();
    expect(screen.getByText("삽입/삭제되는 순서가 서로 반대다.")).toBeInTheDocument();
    expect(screen.getByText("스택은 LIFO, 큐는 FIFO 구조다.")).toBeInTheDocument();

    const details = document.querySelector("details");
    expect(details).not.toBeNull();
    expect(details?.textContent ?? "").toContain("스택과 큐의 가장 큰 차이는 무엇인가요?");
  });

  it("revisions 이력을 revisionNo 내림차순으로 렌더한다", async () => {
    getDraftMock.mockResolvedValue(BASE_DRAFT);

    renderScreen();

    await screen.findByText("설명 보강");
    const bodyText = document.body.textContent ?? "";
    expect(bodyText.indexOf("설명 보강")).toBeLessThan(bodyText.indexOf("선지 순서 수정"));
  });

  it("검수 시작 → 시트 → 제출 시 reviewDraft를 호출하고 잡 화면으로 이동한다", async () => {
    getDraftMock.mockResolvedValue(BASE_DRAFT);
    reviewDraftMock.mockResolvedValue({ jobId: 9 });

    renderScreen();
    await screen.findByText("프로세스는 독립된 자원을 갖는다.");

    fireEvent.click(screen.getByRole("button", { name: "검수 시작" }));
    fireEvent.change(screen.getByLabelText("피드백"), { target: { value: "선지 순서 바꿔줘" } });
    fireEvent.click(screen.getByRole("button", { name: "검수 요청" }));

    await waitFor(() => expect(reviewDraftMock).toHaveBeenCalledWith(5, "선지 순서 바꿔줘"));
    await waitFor(() => expect(mockRouter.push).toHaveBeenCalledWith("/authoring/jobs/9"));
  });

  it("승인 → 확인 시트('승인 즉시 라이브 반영' 경고) → approveDraft → 성공 토스트 + 재조회", async () => {
    getDraftMock.mockResolvedValue(BASE_DRAFT);
    approveDraftMock.mockResolvedValue({ draftId: 5, status: "APPROVED" });

    renderScreen();
    await screen.findByText("프로세스는 독립된 자원을 갖는다.");

    fireEvent.click(screen.getByRole("button", { name: "승인" }));
    expect(await screen.findByText(/승인 즉시 라이브 반영/)).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "승인하기" }));

    await waitFor(() => expect(approveDraftMock).toHaveBeenCalledWith(5));
    expect(await screen.findByText(/승인했어요/)).toBeInTheDocument();
    await waitFor(() => expect(getDraftMock).toHaveBeenCalledTimes(2));
  });

  it("status=APPROVED면 검수·승인 버튼을 렌더하지 않는다", async () => {
    getDraftMock.mockResolvedValue({ ...BASE_DRAFT, status: "APPROVED" });

    renderScreen();

    await screen.findByText("프로세스는 독립된 자원을 갖는다.");
    expect(screen.queryByRole("button", { name: "검수 시작" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "승인" })).not.toBeInTheDocument();
  });

  it("409(AUTHORING_DRAFT_JOB_ACTIVE) 시 진행 중인 잡 안내 토스트를 띄운다", async () => {
    getDraftMock.mockResolvedValue(BASE_DRAFT);
    reviewDraftMock.mockRejectedValue(
      new ApiError({ code: "AUTHORING_DRAFT_JOB_ACTIVE", status: 409, message: "conflict" }),
    );

    renderScreen();
    await screen.findByText("프로세스는 독립된 자원을 갖는다.");

    fireEvent.click(screen.getByRole("button", { name: "검수 시작" }));
    fireEvent.click(screen.getByRole("button", { name: "검수 요청" }));

    expect(await screen.findByText(/진행 중인 잡이 있습니다/)).toBeInTheDocument();
  });

  it("세션 만료(401)면 로그인 화면으로 이동한다", async () => {
    getDraftMock.mockRejectedValue(
      new ApiError({ code: "UNAUTHORIZED", status: 401, message: "unauthorized" }),
    );

    renderScreen();

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/login"));
  });

  it("권한 없음(403)이면 홈으로 이동한다", async () => {
    getDraftMock.mockRejectedValue(
      new ApiError({ code: "FORBIDDEN", status: 403, message: "forbidden" }),
    );

    renderScreen();

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/"));
  });
});
