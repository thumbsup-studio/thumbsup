package studio.thumbsup.server.common.user;

import java.time.LocalDate;

/**
 * {@code user} 도메인이 구현하고 다른 도메인(예: {@code quiz}의 홈 화면 조립)이 소비하는 조회 포트.
 * ArchUnit {@code 피처_간_직접_의존_금지}상 다른 슬라이스가 {@code user}의 리포지토리·서비스를
 * 직접 참조할 수 없어, 필요한 조회 하나만 이 인터페이스로 승격한다(리포지토리 전체 노출 금지).
 */
public interface UserProgressPort {

    UserProgressSnapshot getSnapshot(Long userId, LocalDate today);
}
