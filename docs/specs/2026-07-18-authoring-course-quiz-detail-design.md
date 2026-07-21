# 라이브 문제 코스별 상세 뷰 설계

- 이슈: #182 (M2 — 빠른 보완)
- 브랜치: `feat/182-authoring-course-quiz-detail`
- 범위: `scope: app` + `scope: server`

## 1. 문제 정의

문제 저작 대시보드의 "라이브 문제" 탭(`/authoring/quizzes`)은 지금 문제 **요약**(유형·난이도·질문 텍스트)만 보여준다. 관리자가 각 코스의 문제에 담긴 **키워드·해설(요약/실무예시/오답)·꼬리질문·선택지·정답**을 확인할 방법이 없다.

목표: 코스 → 스텝 → 문제 → 전체 상세를 훑어보는 뷰. 지금은 코스가 OS 1개뿐이지만, 라우트·API·화면 구조를 다중 코스에 맞춰 forward-compatible하게 만든다.

## 2. 데이터 현실 (설계 제약)

- `course` 테이블에 사실상 코스 1개("OS", `V20260711100000__fix_course_title_to_os.sql`).
- `quiz_step`에는 course FK가 **없다**. 스텝들이 어느 코스 소속인지 DB로 구분 불가 → 현재는 모든 스텝이 단일 코스에 암묵적으로 속함.
- 라이브 문제의 전체 상세를 내려주는 read 엔드포인트는 **없다**. 다만 개선(IMPROVE) 플로우가 쓰는 `QuizToGeneratedQuizMapper.toGenerated(Quiz)`가 라이브 `Quiz`를 전체 `GeneratedQuizSet.GeneratedQuiz`(선택지·정답·해설·키워드·꼬리질문+블록)로 이미 변환한다 → **재사용**한다.
- app에는 이 `GeneratedQuiz`를 렌더링하는 로직이 `draft-detail-screen.tsx`의 `QuizPayloadCard`에 이미 있다 → **추출·재사용**한다.

**결정**: speculative한 `quiz_step→course` FK 마이그레이션은 하지 않는다(코스가 하나뿐이라 검증 불가, YAGNI). 대신 API·라우트·화면을 코스 파라미터 구조로 만들어 FK 도입 시 필터만 추가하면 되도록 seam을 남긴다.

## 3. 아키텍처 & 데이터 흐름

```
/authoring/quizzes            →  CoursesIndexScreen (기존 요약 탭 자리 재작성)
                                 GET /authoring/courses → 코스 카드 목록(현재 OS 1개)
        │ 코스 클릭 → /authoring/quizzes/{courseId}
        ▼
/authoring/quizzes/[course]   →  CourseQuizzesScreen (신규)
                                 GET /authoring/courses/{courseId}/quizzes
                                 STEP 아코디언 → 문제 요약 행 → 클릭 → 전체 상세(QuizDetailCard)
```

## 4. 서버 (Spring Boot)

기존 `/api/v1/authoring/**` 엔드포인트와 동일한 ADMIN 게이트(SecurityConfig) 하에 read 엔드포인트 2개 추가.

### 4.1 엔드포인트

```
GET /api/v1/authoring/courses
→ ApiResponse<{ courses: [ { courseId: number, title: string, category: string } ] }>

GET /api/v1/authoring/courses/{courseId}/quizzes
→ ApiResponse<{
    courseId: number,
    title: string,
    steps: [ { stepOrder: number, topic: string | null,
               quizzes: [ { quizId: number, slotOrder: number, generated: GeneratedQuiz } ] } ]
  }>
```

- `courses`: `CourseRepository.findAll()` → DTO 매핑. 지금은 1건.
- `courses/{courseId}/quizzes`:
  - `courseId` 존재 검증 → 없으면 404(기존 에러 규약/`ApiResponse` 형식).
  - 스텝 그룹핑은 `AuthoringQuizService.listQuizzes()`의 정렬·그룹핑 로직 재사용(stepOrder→slotOrder 정렬, `stepOrder > 0` 필터).
  - 각 `Quiz` → `QuizToGeneratedQuizMapper.toGenerated(quiz)`로 `generated` 채움. `generated`의 필드는 draft payload와 **동일 JSON 형태**(app이 이미 파싱·렌더링하는 `GeneratedQuiz`).
  - **다중 코스 seam**: FK가 없어 현재는 `courseId` 검증만 하고 전체 스텝을 반환한다. `quiz_step→course` FK 도입 시 이 지점에서 `courseId`로 스텝을 필터한다(코드 주석으로 명시).

### 4.2 신규/변경 클래스 (예상)

- `AuthoringCourseController` (신규) — 위 2개 GET. 컨트롤러는 얇게(검증·호출·envelope), 엔티티 직접 접근 금지(ArchUnit).
- `AuthoringCourseService` (신규) — 코스 목록·코스별 상세 조립. 상세 조립은 `AuthoringQuizService`의 그룹핑을 재사용(중복이면 private 헬퍼 추출)하고 `QuizToGeneratedQuizMapper`로 매핑.
- DTO(신규): `AuthoringCourseListResponse`, `AuthoringCourseResponse`, `AuthoringCourseDetailResponse`, `AuthoringDetailedStepResponse`, `AuthoringDetailedQuizResponse`(`{ quizId, slotOrder, generated }`).
- 기존 `/authoring/quizzes`(요약)와 `improve`는 그대로 둔다(다른 소비처가 있을 수 있고, 개선 진입점은 상세 뷰에서 계속 쓴다).

### 4.3 테스트

- 컨트롤러 테스트: 코스 목록/코스별 상세 응답 형태, 없는 courseId → 404, ADMIN 아닌 사용자 → 403.
- 서비스/매핑: `generated`가 선택지·정답·해설·키워드·꼬리질문을 온전히 담는지(기존 `QuizToGeneratedQuizMapperTest`가 매핑 자체는 커버 — 조립 레벨만 검증).

## 5. app (Next.js App Router)

### 5.1 파일

```
app/src/app/authoring/quizzes/page.tsx                  (재작성) → CoursesIndexScreen
app/src/app/authoring/quizzes/[course]/page.tsx         (신규)   → CourseQuizzesScreen({courseId})
app/src/features/authoring/components/courses-index-screen.tsx  (신규)
app/src/features/authoring/components/course-quizzes-screen.tsx (신규)
app/src/features/authoring/components/quiz-detail-card.tsx      (신규, 추출)
```

### 5.2 QuizDetailCard 추출 (surgical)

`draft-detail-screen.tsx`의 `QuizPayloadCard`·`FollowUpQuestionItem`·`ExplanationBlock`·`KeywordDictionary`를 `quiz-detail-card.tsx`로 **그대로 이동**해 `QuizDetailCard`로 export. 렌더링 로직·마크업은 변경하지 않는다. `draft-detail-screen`은 이 컴포넌트를 import해서 쓴다(코드 삭제 후 재사용). `slotOrder` prop 유지.

### 5.3 CoursesIndexScreen

- `getAuthoringCourses()` 호출 → 코스 카드 목록. 각 카드: title(+category chip) → `<Link href={/authoring/quizzes/${courseId}}>`.
- 로딩 Skeleton / 에러 Feedback(재시도) / 빈 상태 EmptyState. 401→`/login`, 403→`/` (기존 패턴 동일).

### 5.4 CourseQuizzesScreen (핵심 인터랙션 — 3단 아코디언)

- `getAuthoringCourseQuizzes(courseId)` → `{ title, steps }`.
- 헤더: 코스 title.
- 스텝: 아코디언(드롭다운). 헤더 "STEP {stepOrder} · {topic} · 문제 {n}개", 클릭 시 펼침/접힘. **초기 전체 접힘**.
- 스텝 펼침 → 문제 **요약 행** 목록(유형·난이도 chip + 질문 텍스트 truncate). 각 행 클릭 → 펼쳐지며 `QuizDetailCard`로 전체 상세 노출(다시 클릭 시 접힘).
- 각 문제 상세에 "개선" 버튼 → 기존 `ImproveSheet`(quizId) 재사용.
- 상태는 로컬 `useState`로 열림 집합 관리(스텝 열림 Set, 문제 열림 Set). 데이터 양이 작아 코스 상세를 진입 시 **한 번에 로드**(지연 로딩 없음).
- 접근성: 아코디언 토글은 `<button aria-expanded>` 사용(design-system 규약·기존 패턴 따름).

### 5.5 타입 / API

```ts
// types.ts
export type AuthoringCourse = { courseId: number; title: string; category: string };
export type AuthoringDetailedQuiz = { quizId: number; slotOrder: number; generated: GeneratedQuiz };
export type AuthoringDetailedStep = { stepOrder: number; topic: string | null; quizzes: AuthoringDetailedQuiz[] };
export type AuthoringCourseDetail = { courseId: number; title: string; steps: AuthoringDetailedStep[] };

// api.ts
getAuthoringCourses(): Promise<AuthoringCourse[]>
getAuthoringCourseQuizzes(courseId: number): Promise<AuthoringCourseDetail>
```

## 6. 비-목표 (YAGNI)

- `quiz_step→course` FK 마이그레이션 / 코스별 실제 스텝 분리.
- 코스 생성·편집 UI.
- 페이지네이션(문제 수가 작음).
- 상세의 지연 로딩(코스 상세를 한 번에 로드).

## 7. 완료 기준

- `/authoring/quizzes` 코스 인덱스 → 코스 클릭 → `/authoring/quizzes/[course]` 이동.
- 스텝 아코디언(초기 접힘) → 스텝 펼침 → 문제 행 클릭 → 키워드·해설·꼬리질문·선택지·정답 전체 노출.
- 문제별 "개선" 진입점 유지.
- 서버 신규 엔드포인트 2개 ADMIN 게이트 동작 + 테스트, 없는 courseId 404.
- `verify-app` 게이트(typecheck/lint/build/check:design) + server `./gradlew build` 통과.
