export type AppEnvironment = "development" | "staging" | "production";

export function isStagingEnvironment(value: unknown): value is "staging" {
  return value === "staging";
}

// babel.config.js가 빌드 시점에 APP_ENV를 문자열 리터럴로 바꿔 production 번들에서
// staging 전용 require 분기를 제거할 수 있게 한다.
export const appEnvironment = process.env.APP_ENV as AppEnvironment | undefined;
export const isStagingBuild = isStagingEnvironment(appEnvironment);
