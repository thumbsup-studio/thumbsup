package studio.thumbsup.server.common.event;

import java.time.LocalDate;

/**
 * 유저가 오늘의 학습(1스텝)을 처음 완료했을 때 발행된다. {@code quiz}가 발행하고 {@code user}가
 * 구독해 스트릭·포인트를 갱신한다 — 두 도메인이 서로의 내부(리포지토리·서비스)를 직접 참조하지
 * 않도록 이벤트로만 연결한다(ArchUnit {@code 피처_간_직접_의존_금지}).
 */
public record QuizStepCompletedEvent(Long userId, LocalDate completedOn) {}
