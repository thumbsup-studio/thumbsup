import { render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { RequireAdmin } from "@/features/auth/require-admin";
import { getMyProfile } from "@/lib/api";

const { replaceMock } = vi.hoisted(() => ({ replaceMock: vi.fn() }));

vi.mock("next/navigation", () => ({ useRouter: () => ({ replace: replaceMock }) }));
vi.mock("@/lib/api", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api")>();
  return { ...actual, getMyProfile: vi.fn() };
});

const getMyProfileMock = vi.mocked(getMyProfile);

beforeEach(() => {
  replaceMock.mockReset();
  getMyProfileMock.mockReset();
});

describe("RequireAdmin", () => {
  it("ADMIN에게 대시보드 콘텐츠를 노출한다", async () => {
    getMyProfileMock.mockResolvedValue({ email: "admin@example.com", role: "ADMIN" });

    render(
      <RequireAdmin>
        <p>저작 대시보드</p>
      </RequireAdmin>,
    );

    expect(await screen.findByText("저작 대시보드")).toBeInTheDocument();
  });

  it("ADMIN이 아니면 로그인 화면으로 이동한다", async () => {
    getMyProfileMock.mockResolvedValue({ email: "user@example.com", role: "USER" });

    render(
      <RequireAdmin>
        <p>저작 대시보드</p>
      </RequireAdmin>,
    );

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/login"));
    expect(screen.queryByText("저작 대시보드")).not.toBeInTheDocument();
  });
});
