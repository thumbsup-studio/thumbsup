-- 홈 캐릭터 '보리' 포만감 상태 — 유저당 한 행(#35). 시간 경과에 따른 자연 감소는 조회 시점에
-- 계산하므로(배치·스케줄러 없음), 여기엔 마지막으로 먹인 시점·그때 값만 저장한다.
-- 테이블명은 'character'(MySQL 예약어) 대신 'mascot' 사용 — 엔티티명도 java.lang.Character와의
-- 혼동을 피해 Mascot으로 뒀다.
CREATE TABLE mascot (
    id                    BIGINT      NOT NULL AUTO_INCREMENT,
    user_id               BIGINT      NOT NULL,
    fullness_at_last_feed INT         NOT NULL,
    last_fed_at           DATETIME(6) NOT NULL,
    created_at            DATETIME(6) NOT NULL,
    updated_at            DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_mascot_user UNIQUE (user_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;
