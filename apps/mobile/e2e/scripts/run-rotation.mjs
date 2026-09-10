import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const platform = (process.env.E2E_PLATFORM ?? "android").toLowerCase();
const maestro = process.env.MAESTRO_BIN ?? "maestro";
const device = process.env.E2E_DEVICE_ID;
const flow = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../flows/mobile-native/rotation.yaml");

function run(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8", stdio: "inherit" });
  if (result.status !== 0) throw new Error(`${command} ${args.join(" ")} 실패`);
}

if (platform === "ios") {
  console.log("iOS simctl에는 화면 회전 명령이 없어 회전 검증을 지원하지 않습니다.");
} else if (platform === "android") {
  const maestroArgs = [
    ...(device ? ["--device", device] : []),
    "test",
    "-e",
    `APP_ID=${process.env.APP_ID ?? "studio.thumbsup.staging"}`,
    "-e",
    `E2E_EMAIL=${process.env.E2E_EMAIL ?? ""}`,
    "-e",
    `E2E_PASSWORD=${process.env.E2E_PASSWORD ?? ""}`,
    flow,
  ];
  run("adb", ["shell", "settings", "put", "system", "accelerometer_rotation", "0"]);
  try {
    run("adb", ["shell", "settings", "put", "system", "user_rotation", "1"]);
    run(maestro, maestroArgs);
  } finally {
    run("adb", ["shell", "settings", "put", "system", "user_rotation", "0"]);
  }
  run(maestro, maestroArgs);
} else {
  throw new Error("E2E_PLATFORM은 android 또는 ios여야 합니다.");
}
