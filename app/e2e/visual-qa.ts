import { existsSync } from "node:fs";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { chromium } from "playwright";
import { type QaRoute, qaRoutes } from "./qa-routes";

const targetUrl = process.env.QA_TARGET_URL?.replace(/\/+$/, "");
const apiKey = process.env.ELICE_API_KEY;
const apiBase = process.env.ELICE_QA_BASE_URL?.replace(/\/+$/, "");
const model = process.env.ELICE_QA_MODEL || "gpt-5.2";

const OUT_DIR = path.resolve("e2e/screenshots");
const REPORT_PATH = path.resolve("e2e/qa-report.md");

const VIEWPORTS = [
  { name: "mobile", width: 390, height: 844 },
  { name: "desktop", width: 1280, height: 800 },
] as const;

const HEURISTIC_PROMPT = `당신은 웹 프론트엔드 시각 QA 리뷰어다. 주어진 스크린샷(모바일 390px, 데스크톱 1280px)을 보고 다음 항목만 점검해 한국어로 보고하라.
- 깨진 레이아웃, 요소 겹침·잘림, 가로 스크롤 흔적
- 텍스트 대비 부족, 읽기 어려운 크기
- 터치 타깃 과소(44px 미만으로 보이는 버튼/링크)
- 모바일·데스크톱 반응형 불일치
형식: 문제가 없으면 "✅ 특이사항 없음" 한 줄만. 문제가 있으면 항목당 한 줄로 "🔴|🟡 [뷰포트] 위치 — 증상". 확신 없는 추측성 지적은 쓰지 않는다.`;

const COMPARE_PROMPT = `당신은 디자인 충실도 검사관이다. 첫 번째 이미지는 원본 디자인 시안, 나머지는 실제 구현 스크린샷(모바일, 데스크톱)이다. 시안 대비 구현의 차이만 한국어로 보고하라: 색상, 간격·정렬, 타이포그래피, 누락·변형된 컴포넌트.
형식: 차이가 없으면 "✅ 시안과 일치" 한 줄만. 차이가 있으면 항목당 한 줄로 "🔴|🟡 무엇이 — 어떻게 다른지". 해상도·렌더링 미세 차이는 무시한다.`;

type Shot = { viewport: string; file: string };

async function capture(route: QaRoute): Promise<Shot[]> {
  const browser = await chromium.launch();
  const shots: Shot[] = [];
  try {
    for (const vp of VIEWPORTS) {
      const page = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
      await page.goto(`${targetUrl}${route.path}`, { waitUntil: "networkidle", timeout: 30_000 });
      const slug = route.path === "/" ? "home" : route.path.replaceAll("/", "_").replace(/^_/, "");
      const file = path.join(OUT_DIR, `${slug}-${vp.name}.png`);
      await page.screenshot({ path: file, fullPage: true });
      await page.close();
      shots.push({ viewport: vp.name, file });
      console.log(`📸 ${route.path} [${vp.name}] → ${path.relative(process.cwd(), file)}`);
    }
  } finally {
    await browser.close();
  }
  return shots;
}

async function toImagePart(file: string) {
  const b64 = (await readFile(file)).toString("base64");
  return { type: "image_url", image_url: { url: `data:image/png;base64,${b64}` } };
}

async function review(route: QaRoute, shots: Shot[]): Promise<string> {
  const compareMode = route.design !== null;
  const content: unknown[] = [
    {
      type: "text",
      text: compareMode
        ? `라우트 ${route.path} — 첫 이미지가 시안, 이후 ${shots.map((s) => s.viewport).join(", ")} 구현 스크린샷.`
        : `라우트 ${route.path} — ${shots.map((s) => s.viewport).join(", ")} 스크린샷.`,
    },
  ];
  if (compareMode) content.push(await toImagePart(path.resolve(route.design as string)));
  for (const shot of shots) content.push(await toImagePart(shot.file));

  const res = await fetch(`${apiBase}/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: compareMode ? COMPARE_PROMPT : HEURISTIC_PROMPT },
        { role: "user", content },
      ],
    }),
  });
  if (!res.ok) throw new Error(`엘리스 API ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = (await res.json()) as { choices: { message: { content: string } }[] };
  return data.choices[0]?.message?.content?.trim() || "(빈 응답)";
}

async function main() {
  if (!targetUrl) {
    console.error("QA_TARGET_URL이 필요합니다 (예: https://thumbsup-app-xxx.vercel.app)");
    process.exit(1);
  }
  await rm(REPORT_PATH, { force: true });
  await mkdir(OUT_DIR, { recursive: true });

  const captured: { route: QaRoute; shots: Shot[] }[] = [];
  for (const route of qaRoutes) captured.push({ route, shots: await capture(route) });

  if (!apiKey || !apiBase) {
    console.log(
      "⏭️ ELICE_API_KEY / ELICE_QA_BASE_URL 미설정 — 스크린샷만 저장하고 AI 리뷰는 건너뜁니다.",
    );
    return; // soft skip: 리포트 없음, exit 0
  }

  const sections: string[] = [];
  for (const { route, shots } of captured) {
    try {
      const result = await review(route, shots);
      const mode = route.design ? "시안 대조" : "휴리스틱";
      sections.push(`## \`${route.path}\` (${mode})\n\n${result}`);
      console.log(`✅ 리뷰 완료: ${route.path}`);
    } catch (err) {
      console.error(
        `⚠️ 리뷰 실패(${route.path}): ${(err as Error).message} — 시각 QA를 중단합니다 (soft).`,
      );
      return; // API 장애 시 리포트 미생성, exit 0
    }
  }

  const header = `# 🎨 AI 시각 QA\n\n- 대상: ${targetUrl}\n- 모델: \`${model}\` · 라우트 ${qaRoutes.length}개 × 뷰포트 ${VIEWPORTS.length}종\n- 스크린샷 원본: 워크플로우 아티팩트 \`qa-screenshots\`\n`;
  await writeFile(REPORT_PATH, `${header}\n${sections.join("\n\n")}\n`);
  console.log(`📝 리포트 저장: ${path.relative(process.cwd(), REPORT_PATH)}`);
}

main().catch((err) => {
  console.error(`⚠️ 시각 QA 실패: ${(err as Error).message} — soft gate이므로 성공 종료합니다.`);
  if (existsSync(REPORT_PATH)) rm(REPORT_PATH, { force: true });
});
