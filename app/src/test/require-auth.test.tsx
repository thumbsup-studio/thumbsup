import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { RequireAuth } from "@/features/auth/require-auth";
import { tokenStore } from "@/lib/api";

const { replaceMock } = vi.hoisted(() => ({ replaceMock: vi.fn() }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ replace: replaceMock }) }));

beforeEach(() => {
  replaceMock.mockClear();
  localStorage.clear();
});

describe("RequireAuth", () => {
  it("토큰이 없으면(미로그인) /login으로 replace하고 보호 콘텐츠를 렌더하지 않는다", () => {
    render(
      <RequireAuth>
        <div>보호됨</div>
      </RequireAuth>,
    );

    expect(replaceMock).toHaveBeenCalledWith("/login");
    expect(screen.queryByText("보호됨")).not.toBeInTheDocument();
  });

  it("토큰이 있으면(로그인 상태) 보호 콘텐츠를 렌더하고 리다이렉트하지 않는다", () => {
    tokenStore.set({ accessToken: "a", refreshToken: "r" });

    render(
      <RequireAuth>
        <div>보호됨</div>
      </RequireAuth>,
    );

    expect(screen.getByText("보호됨")).toBeInTheDocument();
    expect(replaceMock).not.toHaveBeenCalled();
  });
});
