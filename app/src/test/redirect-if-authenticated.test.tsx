import { render } from "@testing-library/react";
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
  it("토큰이 있으면(로그인 상태) 홈으로 replace한다", () => {
    tokenStore.set({ accessToken: "a", refreshToken: "r" });

    render(<RedirectIfAuthenticated />);

    expect(replaceMock).toHaveBeenCalledWith("/");
  });

  it("토큰이 없으면 리다이렉트하지 않는다", () => {
    render(<RedirectIfAuthenticated />);

    expect(replaceMock).not.toHaveBeenCalled();
  });
});
