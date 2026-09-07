import { act, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { AppToastProvider, useAppToast } from "@/providers/app-toast-provider";

function ToastHarness() {
  const { showToast } = useAppToast();

  return (
    <div>
      <button
        onClick={() => {
          showToast({ message: "일반 알림입니다." });
        }}
        type="button"
      >
        normal
      </button>
      <button
        onClick={() => {
          showToast({ message: "에러가 발생했습니다.", tone: "error" });
        }}
        type="button"
      >
        error
      </button>
    </div>
  );
}

afterEach(() => {
  vi.useRealTimers();
});

describe("AppToastProvider", () => {
  it("shows and hides a normal toast automatically", () => {
    vi.useFakeTimers();

    render(
      <AppToastProvider>
        <ToastHarness />
      </AppToastProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "normal" }));
    expect(screen.getByText("일반 알림입니다.")).toBeInTheDocument();

    act(() => {
      vi.advanceTimersByTime(3000);
    });
    expect(screen.queryByText("일반 알림입니다.")).not.toBeInTheDocument();
  });

  it("renders an error toast with alert semantics", () => {
    vi.useFakeTimers();

    render(
      <AppToastProvider>
        <ToastHarness />
      </AppToastProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "error" }));

    const alert = screen.getByRole("alert");
    expect(alert).toHaveTextContent("에러가 발생했습니다.");
    expect(alert).toHaveAttribute("data-tone", "error");
  });
});
