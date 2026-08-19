# 라이브 스텝 브리핑 백필 롤아웃 (#299)

`V20260819151604__backfill_live_quiz_step_briefings.sql`은 기존 라이브 스텝에 사람이 검수한 브리핑을 넣는다.
`step_order = 0`인 미배정 placeholder는 대상이 아니다.

## 배포 전 확인

운영 DB에서 아래 조회를 실행한다. 이 조회는 예상한 14개와 실제 라이브 스텝을 양방향으로 대조한다.
**0행**이어야 하며, 이미 브리핑이 있는 행도 함께 검출한다.

```sql
WITH expected (course_title, topic) AS (
    SELECT '운영체제', 'OS 개요와 역할(커널·시스템콜·인터럽트)'
    UNION ALL SELECT '운영체제', '프로세스 기본 개념(PCB·프로세스 상태 전이)'
    UNION ALL SELECT '운영체제', '스레드와 멀티스레딩'
    UNION ALL SELECT '운영체제', 'CPU 스케줄링 기초(FCFS·SJF·라운드로빈·우선순위)'
    UNION ALL SELECT '운영체제', 'CPU 스케줄링 심화(선점형·비선점형·멀티레벨 큐·기아와 에이징)'
    UNION ALL SELECT '운영체제', '프로세스 동기화 기초(임계구역·뮤텍스·세마포어)'
    UNION ALL SELECT '운영체제', '동기화 심화(생산자-소비자 문제·모니터·경쟁 상태)'
    UNION ALL SELECT '운영체제', '교착상태(4대 조건·예방·회피·탐지·복구)'
    UNION ALL SELECT '운영체제', '메모리 관리 기초(연속 할당·단편화·페이징·세그멘테이션)'
    UNION ALL SELECT '운영체제', '가상 메모리(페이지 폴트·페이지 교체 알고리즘·스래싱)'
    UNION ALL SELECT '운영체제', '파일 시스템(파일 구조·디렉토리·할당 방식)'
    UNION ALL SELECT '운영체제', '입출력과 디스크 관리(버퍼링·스풀링·디스크 스케줄링)'
    UNION ALL SELECT '디자인 패턴', '생성 패턴 개요와 싱글턴(스레드 안전성 포함)'
    UNION ALL SELECT '디자인 패턴', '팩토리 메서드와 추상 팩토리'
),
live_steps AS (
    SELECT c.title AS course_title, qs.topic, qsb.id AS briefing_id
    FROM quiz_step qs
    JOIN course c ON c.id = qs.course_id
    LEFT JOIN quiz_step_briefing qsb ON qsb.quiz_step_id = qs.id
    WHERE qs.step_order > 0
)
SELECT 'EXPECTED_MISSING_OR_DUPLICATED' AS issue, expected.course_title, expected.topic
FROM expected
LEFT JOIN live_steps
    ON live_steps.course_title = expected.course_title AND live_steps.topic = expected.topic
GROUP BY expected.course_title, expected.topic
HAVING COUNT(live_steps.topic) <> 1
UNION ALL
SELECT 'UNEXPECTED_LIVE_STEP', live_steps.course_title, live_steps.topic
FROM live_steps
LEFT JOIN expected
    ON expected.course_title = live_steps.course_title AND expected.topic = live_steps.topic
WHERE expected.topic IS NULL
UNION ALL
SELECT 'BRIEFING_ALREADY_PRESENT', live_steps.course_title, live_steps.topic
FROM live_steps
WHERE live_steps.briefing_id IS NOT NULL;
```

행이 반환되면 이 마이그레이션을 배포하지 않는다. 기존 데이터의 출처를 확인한 뒤 별도 보정
마이그레이션을 만든다. 본 마이그레이션도 같은 불일치를 감지하면 실패하도록 가드한다.

## 롤아웃과 배포 후 확인

1. 이 마이그레이션을 포함한 PR을 main에 병합한다. 서버 배포 시 Flyway가 자동 적용한다.
2. 배포가 끝난 뒤 아래 조회가 **0행**인지 확인한다. 0행이면 모든 라이브 스텝이 브리핑 하나를 가지며,
   블록 수와 표시 순서가 유효하다는 뜻이다.

```sql
SELECT qs.id,
       c.title AS course_title,
       qs.step_order,
       qs.topic,
       COUNT(DISTINCT qsb.id) AS briefing_count,
       COUNT(qsbb.id) AS block_count,
       MIN(qsbb.display_order) AS first_block_order,
       MAX(qsbb.display_order) AS last_block_order
FROM quiz_step qs
JOIN course c ON c.id = qs.course_id
LEFT JOIN quiz_step_briefing qsb ON qsb.quiz_step_id = qs.id
LEFT JOIN quiz_step_briefing_block qsbb ON qsbb.briefing_id = qsb.id
WHERE qs.step_order > 0
GROUP BY qs.id, c.title, qs.step_order, qs.topic
HAVING COUNT(DISTINCT qsb.id) <> 1
    OR COUNT(qsbb.id) NOT BETWEEN 2 AND 4
    OR MIN(qsbb.display_order) <> 1
    OR MAX(qsbb.display_order) <> COUNT(qsbb.id);
```

Flyway 이력도 함께 확인한다.

```sql
SELECT version, description, success
FROM flyway_schema_history
WHERE version = '20260819151604';
```

`success = 1`이 아니거나 위 검증 조회가 행을 반환하면, 수동 데이터 수정 대신 원인을 분석한 뒤 새 Flyway
보정 마이그레이션으로 처리한다. 이미 적용된 Flyway 파일의 checksum은 변경하지 않는다.
