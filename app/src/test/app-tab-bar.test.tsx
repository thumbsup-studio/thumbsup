import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { AppTabBar } from "@/components/app-tab-bar";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { pushMock } = vi.hoisted(() => ({ pushMock: vi.fn() }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));

function renderTabBar(activeTab: "home" | "history" | "profile") {
  return render(
    <AppToastProvider>
      <AppTabBar activeTab={activeTab} />
    </AppToastProvider>,
  );
}

describe("AppTabBar", () => {
  it("uses the full home png icon when the home tab is active", () => {
    renderTabBar("home");

    const homeTab = screen.getByRole("button", { name: "홈" });
    const historyTab = screen.getByRole("button", { name: "히스토리" });
    const homeIcon = homeTab.querySelector('img[alt=""]');
    const historyIcon = historyTab.querySelector('img[alt=""]');

    expect(homeTab).toHaveAttribute("aria-current", "page");
    expect(homeTab).toHaveAttribute("data-state", "active");
    expect(historyTab).toHaveAttribute("data-state", "inactive");
    expect(homeTab.querySelector("[data-icon-variant]")).toHaveAttribute(
      "data-icon-variant",
      "full",
    );
    expect(historyTab.querySelector("[data-icon-variant]")).toHaveAttribute(
      "data-icon-variant",
      "empty",
    );
    expect(homeIcon).toHaveAttribute("src", "/icons/tabs/home-full.png");
    expect(historyIcon).toHaveAttribute("src", "/icons/tabs/history-empty.png");
  });

  it("uses the full history png icon when the history tab is active", () => {
    renderTabBar("history");

    const historyTab = screen.getByRole("button", { name: "히스토리" });
    const profileTab = screen.getByRole("button", { name: "프로필" });
    const historyIcon = historyTab.querySelector('img[alt=""]');

    expect(historyTab).toHaveAttribute("aria-current", "page");
    expect(historyTab).toHaveAttribute("data-state", "active");
    expect(profileTab).toHaveAttribute("data-state", "inactive");
    expect(historyTab.querySelector("[data-icon-variant]")).toHaveAttribute(
      "data-icon-variant",
      "full",
    );
    expect(historyIcon).toHaveAttribute("src", "/icons/tabs/history-full.png");
  });

  it("routes to /history when the history tab is pressed from another tab", () => {
    pushMock.mockClear();
    renderTabBar("home");

    fireEvent.click(screen.getByRole("button", { name: "히스토리" }));

    expect(pushMock).toHaveBeenCalledWith("/history");
  });

  it("routes to /profile when the profile tab is pressed", () => {
    pushMock.mockClear();
    renderTabBar("home");

    fireEvent.click(screen.getByRole("button", { name: "프로필" }));

    expect(pushMock).toHaveBeenCalledWith("/profile");
  });

  it("does not navigate when the already-active tab is pressed", () => {
    pushMock.mockClear();
    renderTabBar("history");

    fireEvent.click(screen.getByRole("button", { name: "히스토리" }));

    expect(pushMock).not.toHaveBeenCalled();
  });
});
