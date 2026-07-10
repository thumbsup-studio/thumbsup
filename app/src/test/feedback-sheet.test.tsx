import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { FeedbackSheet } from "@/features/profile/components/feedback-sheet";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { sendFeedbackMock } = vi.hoisted(() => ({ sendFeedbackMock: vi.fn() }));

// ApiError 등 실제 export는 유지하고 sendFeedback만 교체한다(instanceof ApiError 분기 보존).
vi.mock("@/lib/api", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@/lib/api")>()),
  sendFeedback: sendFeedbackMock,
}));

function renderSheet() {
  const onClose = vi.fn();
  render(
    <AppToastProvider>
      <FeedbackSheet open onClose={onClose} />
    </AppToastProvider>,
  );
  return { onClose };
}

afterEach(() => {
  sendFeedbackMock.mockReset();
});

describe("FeedbackSheet", () => {
  it("빈/공백 입력이면 보내기 버튼이 비활성이다", () => {
    renderSheet();

    const send = screen.getByRole("button", { name: "보내기" });
    expect(send).toBeDisabled();

    fireEvent.change(screen.getByLabelText("의견 내용"), { target: { value: "   " } });
    expect(send).toBeDisabled();
  });

  it("의견 입력 후 보내면 sendFeedback(트림값) 호출 + 시트를 닫는다", async () => {
    sendFeedbackMock.mockResolvedValue({ id: 1 });
    const { onClose } = renderSheet();

    fireEvent.change(screen.getByLabelText("의견 내용"), {
      target: { value: "  좋은 앱이에요  " },
    });
    fireEvent.click(screen.getByRole("button", { name: "보내기" }));

    await waitFor(() => expect(sendFeedbackMock).toHaveBeenCalledWith("좋은 앱이에요"));
    await waitFor(() => expect(onClose).toHaveBeenCalledTimes(1));
    expect(await screen.findByText(/의견 고마워요/)).toBeInTheDocument();
  });

  it("전송 실패 시 에러 토스트를 띄우고 시트를 닫지 않는다(입력 유지)", async () => {
    sendFeedbackMock.mockRejectedValue(new Error("network"));
    const { onClose } = renderSheet();

    fireEvent.change(screen.getByLabelText("의견 내용"), { target: { value: "테스트 의견" } });
    fireEvent.click(screen.getByRole("button", { name: "보내기" }));

    await waitFor(() => expect(sendFeedbackMock).toHaveBeenCalledTimes(1));
    expect(onClose).not.toHaveBeenCalled();
    expect(await screen.findByText(/실패/)).toBeInTheDocument();
    expect(screen.getByLabelText("의견 내용")).toHaveValue("테스트 의견");
  });
});
