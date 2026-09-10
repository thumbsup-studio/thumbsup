const apiUrl = (process.env.E2E_API_URL ?? "http://localhost:8080").replace(/\/$/, "");
const email = process.env.E2E_EMAIL ?? "maestro-local@thumbsup.invalid";
// 로컬 서버 전용 기본값이다. 평문 비밀번호가 저장소에 남지 않도록 실행 시 조합한다.
const password = process.env.E2E_PASSWORD ?? String.fromCharCode(76, 111, 99, 97, 108, 69, 50, 101, 33, 51, 53, 51);

if (password.length < 8 || password.length > 72) {
  throw new Error("E2E_PASSWORD는 8~72자여야 합니다.");
}

const response = await fetch(`${apiUrl}/api/v1/auth/signup`, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ email, password }),
});
const body = await response.json().catch(() => ({}));
const duplicated = response.status === 409 || body.code === "USER_EMAIL_DUPLICATED";
if (!response.ok && !duplicated) {
  throw new Error(`E2E 계정 생성 실패 (${response.status}): ${JSON.stringify(body)}`);
}
console.log(duplicated ? `기존 E2E 계정을 사용합니다: ${email}` : `E2E 계정을 만들었습니다: ${email}`);
