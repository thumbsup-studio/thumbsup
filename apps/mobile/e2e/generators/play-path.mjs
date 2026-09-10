import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const directory = path.dirname(fileURLToPath(import.meta.url));
const coreDirectory = path.resolve(directory, "../../../../packages/core/src");
const jsonPath = path.join(directory, "play-paths.generated.json");
const yamlPath = path.resolve(directory, "../flows/routes/play.generated.yaml");

async function importTypeScript(file) {
  const source = await readFile(file, "utf8");
  const javascript = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
    fileName: file,
  }).outputText;
  return import(`data:text/javascript;base64,${Buffer.from(javascript).toString("base64")}`);
}

export async function buildPaths() {
  const [logic, session] = await Promise.all([
    importTypeScript(path.join(coreDirectory, "play-logic.ts")),
    importTypeScript(path.join(coreDirectory, "mock-play-session.ts")),
  ]);
  const questions = session.mockPlaySession.questions;
  const kinds = ["ox", "multiple-choice", "keyword-blank"];
  const paths = [];

  for (const kind of kinds) {
    const questionIndex = questions.findIndex((question) => question.kind === kind);
    if (questionIndex < 0) throw new Error(`mock play session에서 ${kind} 문제를 찾지 못했습니다.`);
    if (logic.clampQuestionIndex(questionIndex, questions.length) !== questionIndex) {
      throw new Error(`${kind} 문제 인덱스를 상태 모델이 보존하지 못했습니다.`);
    }
    if (logic.getProgressPercent(questionIndex, questions.length) <= 0) {
      throw new Error(`${kind} 문제 진행률이 올바르지 않습니다.`);
    }
    const question = questions[questionIndex];
    for (const answerMode of ["correct", "incorrect"]) {
      let draft;
      let answerSelector = "";
      let answerText = "";
      if (kind === "ox") {
        draft = answerMode === "correct" ? question.answer : !question.answer;
        answerSelector = draft ? "O, 맞다" : "X, 아니다";
      } else if (kind === "multiple-choice") {
        const option = question.options.find((item) =>
          answerMode === "correct" ? item.id === question.answerId : item.id !== question.answerId,
        );
        if (!option) throw new Error(`${kind} ${answerMode} 선택지를 만들지 못했습니다.`);
        draft = option.id;
        const optionIndex = question.options.indexOf(option);
        answerSelector = `${String.fromCharCode(65 + optionIndex)}. ${option.label}`;
      } else {
        answerText = answerMode === "correct" ? question.acceptedAnswers[0] : "공유 자원";
        draft = logic.normalizeKeywordAnswer(answerText);
      }
      if (!logic.canSubmitAnswer(question, draft)) {
        throw new Error(`${kind} ${answerMode} 경로를 제출할 수 없습니다.`);
      }
      if (logic.gradeMockAnswer(question, draft).correct !== (answerMode === "correct")) {
        throw new Error(`${kind} ${answerMode} 경로의 채점 결과가 일치하지 않습니다.`);
      }
      paths.push({
        id: `${kind === "multiple-choice" ? "choice" : kind === "keyword-blank" ? "keyword" : kind}-${answerMode}${answerMode === "incorrect" ? "-hint" : ""}`,
        QUESTION_KIND: kind === "keyword-blank" ? "keyword" : kind,
        ANSWER_MODE: answerMode,
        USE_HINT: answerMode === "incorrect" ? "true" : "false",
        ANSWER_SELECTOR: answerSelector,
        ANSWER_TEXT: answerText,
      });
    }
  }
  return paths;
}

function renderJson(paths) {
  return `${JSON.stringify(paths, null, 2)}\n`;
}

function renderYaml(paths) {
  const runs = paths
    .map(
      (entry) => `- runFlow:\n    when:\n      true: \${PLAY_PATH == '${entry.id}'}\n    file: ../atoms/play-one-question.yaml\n    env:\n      QUESTION_KIND: ${entry.QUESTION_KIND}\n      ANSWER_MODE: ${entry.ANSWER_MODE}\n      USE_HINT: "${entry.USE_HINT}"\n      ANSWER_SELECTOR: "${entry.ANSWER_SELECTOR}"\n      ANSWER_TEXT: "${entry.ANSWER_TEXT}"`,
    )
    .join("\n");
  return `appId: \${APP_ID}\nname: Route - generated play path\ntags: [route, generated]\nenv:\n  PLAY_PATH: \${PLAY_PATH || 'ox-correct'}\n---\n- runFlow: ../atoms/login.yaml\n- tapOn: "시작하기"\n- tapOn: "문제 풀기"\n${runs}\n`;
}

const paths = await buildPaths();
if (paths.length > 6) throw new Error("play 경로는 6개 이하여야 합니다.");
const expected = new Map([
  [jsonPath, renderJson(paths)],
  [yamlPath, renderYaml(paths)],
]);

if (process.argv.includes("--check")) {
  const stale = [];
  for (const [file, content] of expected) {
    try {
      if ((await readFile(file, "utf8")) !== content) stale.push(path.relative(process.cwd(), file));
    } catch {
      stale.push(path.relative(process.cwd(), file));
    }
  }
  if (stale.length) {
    console.error(`play 경로 생성물이 최신이 아닙니다: ${stale.join(", ")}`);
    process.exitCode = 1;
  } else {
    console.log(`play 경로 생성물 일치 (${paths.length}개)`);
  }
} else {
  for (const [file, content] of expected) await writeFile(file, content);
  console.log(`play 경로 ${paths.length}개를 생성했습니다.`);
}
