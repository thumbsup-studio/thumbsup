import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { renderNativeWindV4Preset, renderWebTheme } from "../src/generate";

const generated = fileURLToPath(new URL("../generated/", import.meta.url));

describe("generated design tokens", () => {
  it("keeps the checked-in web theme identical to the SSOT", () => {
    expect(readFileSync(`${generated}web-theme.css`, "utf8")).toBe(renderWebTheme());
    expect(renderWebTheme()).toMatchSnapshot();
  });

  it("keeps the NativeWind v4 preset identical to the SSOT", () => {
    expect(readFileSync(`${generated}nativewind-v4.preset.cjs`, "utf8")).toBe(
      renderNativeWindV4Preset(),
    );
    expect(renderNativeWindV4Preset()).toMatchSnapshot();
  });
});
