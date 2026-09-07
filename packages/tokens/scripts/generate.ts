import { writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { renderNativeWindV4Preset, renderWebTheme } from "../src/generate";

const generated = fileURLToPath(new URL("../generated/", import.meta.url));

await Promise.all([
  writeFile(`${generated}web-theme.css`, renderWebTheme()),
  writeFile(`${generated}nativewind-v4.preset.cjs`, renderNativeWindV4Preset()),
]);
