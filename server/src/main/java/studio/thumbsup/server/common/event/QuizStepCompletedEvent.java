package studio.thumbsup.server.common.event;

import java.time.LocalDate;

/**
 * 유저가 오늘의 학습(1스텝)을 처음 완료했을 때 발행된다. {@code quiz}가 발행하고 {@code user}가
 * 구독해 스트릭·포인트를 갱신한다 — 두 도메인이 서로의 내부(리포지토리·서비스)를 직접 참조하지
 * 않도록 이벤트로만 연결한다(ArchUnit {@code 피처_간_직접_의존_금지}).
 *
 * <p>{@code quizStepId}는 {@code quiz.concept.LearnedConceptRecorder}(#233)도 같은 이벤트를
 * 동기 구독해 지식 그래프 학습 기록을 남기는 데 쓴다 — 퀴즈 id 목록처럼 quiz 내부 구현 세부사항까지
 * 이벤트에 싣지 않고, 그 리스너가 필요하면 quizStepId로 직접 조회하게 한다. step_order가 아니라
 * quizStepId를 싣는 이유(#292)는 step_order가 코스마다 겹칠 수 있는 값이라서다.
 */
public record QuizStepCompletedEvent(Long userId, LocalDate completedOn, Long quizStepId) {}
