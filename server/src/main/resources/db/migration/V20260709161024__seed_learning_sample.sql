-- 샘플 코스 "CS 기초" + 화 10개 + 유저 진행상태 데모 2건 — #45 홈 API 동작·테스트 검증용 임시 데이터.
-- 실제 커리큘럼 콘텐츠·유저 진행 갱신 로직은 후속 티켓이 대체한다. 수동 편집 금지(적용된 마이그레이션 규칙).

INSERT INTO course (id, title, category, created_at, updated_at)
VALUES (1, 'CS 기초', 'CS', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

INSERT INTO unit (course_id, order_index, title, estimated_minutes, created_at, updated_at)
VALUES (1, 1, '배열과 리스트', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
       (1, 2, '스택과 큐', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
       (1, 3, '해시 테이블', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
       (1, 4, '트리', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
       (1, 5, '힙(우선순위 큐)', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
       (1, 6, '정렬', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
       (1, 7, '이진 탐색', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
       (1, 8, '동적 계획법', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
       (1, 9, '그리디 알고리즘', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
       (1, 10, '그래프 탐색(BFS/DFS)', 3, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

-- user_id 1·2는 auth.users 시드가 아직 없어도 무방하다 — user_progress는 ID 값으로만 참조하고
-- FK 제약이 없다(다른 도메인 참조 규칙).
INSERT INTO user_progress (user_id, course_id, cursor_unit_index, streak, points, created_at, updated_at)
VALUES (1, 1, 3, 5, 320, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)),
       (2, 1, 7, 1, 90, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));
