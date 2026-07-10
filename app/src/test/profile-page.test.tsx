import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { ProfilePage } from "@/features/profile/components/profile-page";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { backMock, replaceMock, logoutMock } = vi.hoisted(() => ({
  backMock: vi.fn(),
  replaceMock: vi.fn(),
  logoutMock: vi.fn().mockResolvedValue(undefined),
}));

vi.mock("next/navigation", () => ({
  useRouter: () => ({ back: backMock, replace: replaceMock }),
}));
vi.mock("@/lib/api", () => ({ logout: logoutMock }));

function renderProfile(email = "jiyeon.kim@example.com") {
  return render(
    <AppToastProvider>
      <ProfilePage data={{ email }} />
    </AppToastProvider>,
  );
}

afterEach(() => {
  backMock.mockClear();
  replaceMock.mockClear();
  logoutMock.mockClear();
});

describe("ProfilePage", () => {
  it("이메일과 이메일 이니셜 아바타를 표시한다", () => {
    renderProfile("jiyeon.kim@example.com");

    expect(screen.getByText("jiyeon.kim@example.com")).toBeInTheDocument();
    expect(screen.getByText("J")).toBeInTheDocument();
  });

  it("미구현 설정 항목을 탭하면 준비 중 토스트를 띄운다", () => {
    renderProfile();

    fireEvent.click(screen.getByRole("button", { name: "계정 설정" }));
    expect(screen.getByText("계정 설정은 준비 중입니다.")).toBeInTheDocument();
  });

  it("로그아웃 확인 → 완료 화면 → 로그인 화면 이동", async () => {
    renderProfile();

    fireEvent.click(screen.getByRole("button", { name: "로그아웃" }));
    expect(screen.getByRole("dialog", { name: "로그아웃 확인" })).toBeInTheDocument();

    // 시트가 열리면 "로그아웃" 버튼이 둘(본문 + 시트 확인) — 시트 확인 버튼을 누른다.
    const logoutButtons = screen.getAllByRole("button", { name: "로그아웃" });
    fireEvent.click(logoutButtons[logoutButtons.length - 1]);

    await waitFor(() => expect(logoutMock).toHaveBeenCalledTimes(1));
    expect(await screen.findByText("로그아웃되었습니다")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "로그인 화면으로" }));
    expect(replaceMock).toHaveBeenCalledWith("/login");
  });

  it("확인 시트에서 취소하면 로그아웃하지 않고 시트를 닫는다", () => {
    renderProfile();

    fireEvent.click(screen.getByRole("button", { name: "로그아웃" }));
    fireEvent.click(screen.getByRole("button", { name: "취소" }));

    expect(logoutMock).not.toHaveBeenCalled();
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("헤더의 뒤로가기 버튼은 router.back을 호출한다", () => {
    renderProfile();

    fireEvent.click(screen.getByRole("button", { name: "뒤로" }));
    expect(backMock).toHaveBeenCalledTimes(1);
  });
});
