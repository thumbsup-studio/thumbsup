import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { RedirectIfAuthenticated } from "@/features/auth/redirect-if-authenticated";
import { tokenStore } from "@/lib/api";

const { replaceMock } = vi.hoisted(() => ({ replaceMock: vi.fn() }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ replace: replaceMock }) }));

beforeEach(() => {
  replaceMock.mockClear();
  localStorage.clear();
});

describe("RedirectIfAuthenticated", () => {
  it("토큰이 있으면(로그인 상태) 홈으로 replace하고 인증 화면을 렌더하지 않는다", () => {
    tokenStore.set({ accessToken: "a", refreshToken: "r" });

    render(
      <RedirectIfAuthenticated>
        <div>로그인 폼</div>
      </RedirectIfAuthenticated>,
    );

    expect(replaceMock).toHaveBeenCalledWith("/");
    expect(screen.queryByText("로그인 폼")).not.toBeInTheDocument();
  });

  it("토큰이 없으면 인증 화면(children)을 렌더하고 리다이렉트하지 않는다", () => {
    render(
      <RedirectIfAuthenticated>
        <div>로그인 폼</div>
      </RedirectIfAuthenticated>,
    );

    expect(screen.getByText("로그인 폼")).toBeInTheDocument();
    expect(replaceMock).not.toHaveBeenCalled();
  });
});
