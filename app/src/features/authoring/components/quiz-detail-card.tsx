import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import type {
  GeneratedFollowUpQuestion,
  GeneratedQuiz,
  GeneratedQuizKeyword,
} from "@/features/authoring/types";

export function QuizDetailCard({ quiz, slotOrder }: { quiz: GeneratedQuiz; slotOrder: number }) {
  return (
    <Card className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <span className="text-sm font-semibold text-ink-muted">{slotOrder}</span>
        <Chip tone="neutral">{quiz.type}</Chip>
        <Chip tone="neutral">{quiz.difficulty}</Chip>
      </div>
      {/* [[마커]]는 사전 용어 표기 규칙(정확히 1회 등장) 검수 대상이라 변환 없이 원문 그대로 노출한다. */}
      <p className="text-base font-semibold text-ink">{quiz.questionText}</p>
      {quiz.codeSnippet ? (
        <pre className="overflow-x-auto rounded-control border border-border bg-ink px-4 py-3 text-primary-fg text-sm">
          <code>{quiz.codeSnippet}</code>
        </pre>
      ) : null}
      {quiz.choices ? (
        <ul className="flex flex-col gap-1.5">
          {quiz.choices.map((choice) => (
            <li
              className={`rounded-control px-3 py-2 text-sm ${
                choice.isCorrect
                  ? "bg-success/10 font-semibold text-success"
                  : "bg-surface-muted text-ink-muted"
              }`}
              key={choice.content}
            >
              {choice.content}
              {choice.isCorrect ? " (정답)" : null}
            </li>
          ))}
        </ul>
      ) : null}
      {/* choices가 없는 OX 문제는 이 표시가 화면상 유일한 정답 단서다. */}
      {quiz.correctAnswer ? (
        <p
          className={`rounded-control px-3 py-2 text-sm font-semibold ${
            quiz.correctAnswer === "O" ? "bg-success/10 text-success" : "bg-danger/10 text-danger"
          }`}
        >
          정답: {quiz.correctAnswer}
        </p>
      ) : null}
      {quiz.answerKeywords ? (
        <div className="flex flex-col gap-1.5">
          <span className="text-xs font-semibold text-ink-muted">정답(빈칸별 동의어)</span>
          <ul className="flex flex-col gap-1.5">
            {quiz.answerKeywords.map((synonyms, index) => (
              <li
                className="rounded-control bg-success/10 px-3 py-2 text-sm font-semibold text-success"
                key={synonyms.join("|")}
              >
                빈칸 {index + 1}: {synonyms.join(" / ")}
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      <div className="flex flex-col gap-3 border-border border-t pt-3">
        <ExplanationBlock label="요약" text={quiz.explanationSummary} />
        {quiz.explanationExample ? (
          <ExplanationBlock label="실무 예시" text={quiz.explanationExample} />
        ) : null}
        <ExplanationBlock label="오답 해설" text={quiz.wrongAnswerExplanation} />
      </div>

      {quiz.keywords ? (
        <div className="flex flex-col gap-1.5">
          <span className="text-xs font-semibold text-ink-muted">키워드</span>
          <KeywordDictionary keywords={quiz.keywords} />
        </div>
      ) : null}

      {quiz.derivedConcepts ? (
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs font-semibold text-ink-muted">파생 개념</span>
          {quiz.derivedConcepts.map((concept) => (
            <Chip key={concept} tone="neutral">
              {concept}
            </Chip>
          ))}
        </div>
      ) : null}

      {quiz.followUpQuestions && quiz.followUpQuestions.length > 0 ? (
        <details className="rounded-control border border-border bg-surface-muted px-3 py-2">
          <summary className="cursor-pointer text-sm font-semibold text-ink">
            꼬리질문 {quiz.followUpQuestions.length}개
          </summary>
          <ul className="mt-3 flex flex-col gap-3">
            {quiz.followUpQuestions.map((followUp) => (
              <FollowUpQuestionItem followUp={followUp} key={followUp.content} />
            ))}
          </ul>
        </details>
      ) : null}
    </Card>
  );
}

function FollowUpQuestionItem({ followUp }: { followUp: GeneratedFollowUpQuestion }) {
  return (
    <li className="flex flex-col gap-2 rounded-control bg-surface p-3">
      <div className="flex flex-wrap items-center gap-2">
        <p className="font-semibold text-ink text-sm">{followUp.content}</p>
        {followUp.isPrimary ? <Chip tone="primary">대표질문</Chip> : null}
        <Chip tone="neutral">{followUp.difficulty}</Chip>
      </div>
      <ExplanationBlock label="한 줄 답변" text={followUp.oneLineAnswer} />
      {followUp.blocks.map((block) => (
        <ExplanationBlock key={block.label} label={block.label} text={block.content} />
      ))}
      {followUp.keywords.length > 0 ? <KeywordDictionary keywords={followUp.keywords} /> : null}
    </li>
  );
}

function ExplanationBlock({ label, text }: { label: string; text: string }) {
  return (
    <div className="flex flex-col gap-1">
      <span className="text-xs font-semibold text-ink-muted">{label}</span>
      <p className="text-sm text-ink-muted">{text}</p>
    </div>
  );
}

function KeywordDictionary({ keywords }: { keywords: GeneratedQuizKeyword[] }) {
  return (
    <dl className="flex flex-col gap-1.5">
      {keywords.map((kw) => (
        <div
          className="flex flex-col gap-0.5 rounded-control bg-surface-muted px-3 py-2"
          key={kw.keyword}
        >
          <dt className="font-semibold text-ink text-sm">{kw.keyword}</dt>
          <dd className="text-ink-muted text-sm">{kw.description}</dd>
        </div>
      ))}
    </dl>
  );
}
