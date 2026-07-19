# 라이브 문제 코스별 상세 뷰 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 문제 저작 대시보드에서 코스 → 스텝(아코디언) → 문제(클릭) → 전체 상세(키워드·해설·꼬리질문·선택지·정답)를 열람하는 뷰를 추가한다.

**Architecture:** 서버는 기존 `QuizToGeneratedQuizMapper`(개선 플로우가 쓰는 라이브 Quiz→GeneratedQuiz 역매핑)를 재사용해 read 엔드포인트 2개(`GET /authoring/courses`, `GET /authoring/courses/{courseId}/quizzes`)를 추가한다. app은 기존 `/authoring/quizzes` 요약 탭을 코스 인덱스로 바꾸고, 신규 `/authoring/quizzes/[course]` 상세 화면에서 `draft-detail-screen`의 렌더링을 추출한 `QuizDetailCard`로 상세를 그린다.

**Tech Stack:** Spring Boot(Java 21) · Next.js(App Router) · TypeScript · Tailwind v4 토큰 · Vitest + Testing Library · JUnit5 + standalone MockMvc

## Global Constraints

- main 직접 커밋 금지. 작업 브랜치: `feat/182-authoring-course-quiz-detail` (이미 생성됨, worktree `~/DEV/thumbsup__worktrees/feat-182-authoring-course-quiz-detail`).
- 커밋 형식: `<type>(<scope>): <한국어 요약> (#182)`, scope ∈ {app, server}. 커밋 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- 서버: 컨트롤러는 얇게(검증·호출·envelope), 엔티티 직접 접근 금지(ArchUnit). 모든 응답은 `ApiResponse<T>` envelope. 에러 코드 값 = enum 이름(배포 후 변경 금지).
- 서버 보안: `/api/v1/authoring/**`는 SecurityConfig에서 이미 `hasRole("ADMIN")` — 신규 엔드포인트도 자동 적용, **SecurityConfig 수정 금지**.
- app: 스타일은 globals.css `@theme` 토큰 + `src/components/ui` 컴포넌트만(arbitrary value·raw hex 금지, `check:design` 게이트가 강제). `'use client'`는 상호작용 최소 단위에만.
- app API 소비: `apiRequest`가 envelope를 언랩. 401(재발급 실패)→`/login`, 403→`/` 리다이렉트(기존 authoring 화면 패턴 동일).
- 완료 기준: app은 `verify-app` 게이트(typecheck→lint→build→check:design), 서버는 `./gradlew build` 통과.
- 서버 `GET /authoring/quizzes`(요약) 및 `getAuthoringQuizzes`(app)는 **건드리지 않는다**(범위 밖). 신규 코스 엔드포인트를 나란히 추가한다.

---

## File Structure

**서버 (신규)**
- `server/src/main/java/studio/thumbsup/server/quiz/authoring/AuthoringCourseController.java` — GET /courses, /courses/{id}/quizzes
- `server/src/main/java/studio/thumbsup/server/quiz/authoring/AuthoringCourseService.java` — 코스 목록·코스별 상세 조립
- `server/src/main/java/studio/thumbsup/server/quiz/authoring/dto/AuthoringCourseResponse.java`
- `server/src/main/java/studio/thumbsup/server/quiz/authoring/dto/AuthoringCourseListResponse.java`
- `server/src/main/java/studio/thumbsup/server/quiz/authoring/dto/AuthoringDetailedQuizResponse.java`
- `server/src/main/java/studio/thumbsup/server/quiz/authoring/dto/AuthoringDetailedStepResponse.java`
- `server/src/main/java/studio/thumbsup/server/quiz/authoring/dto/AuthoringCourseDetailResponse.java`

**서버 (수정)**
- `server/src/main/java/studio/thumbsup/server/quiz/authoring/AuthoringErrorType.java` — `AUTHORING_COURSE_NOT_FOUND` 추가

**서버 (테스트)**
- `server/src/test/java/studio/thumbsup/server/quiz/authoring/AuthoringCourseControllerTest.java`

**app (신규)**
- `app/src/features/authoring/components/quiz-detail-card.tsx` — `draft-detail-screen`에서 추출한 상세 렌더러
- `app/src/features/authoring/components/courses-index-screen.tsx`
- `app/src/features/authoring/components/course-quizzes-screen.tsx`
- `app/src/app/authoring/quizzes/[course]/page.tsx`

**app (수정)**
- `app/src/features/authoring/types.ts` — 코스 타입 추가
- `app/src/features/authoring/api.ts` — `getAuthoringCourses`, `getAuthoringCourseQuizzes`
- `app/src/features/authoring/components/draft-detail-screen.tsx` — 추출한 `QuizDetailCard` import로 교체
- `app/src/app/authoring/quizzes/page.tsx` — `CoursesIndexScreen` 렌더로 교체

**app (삭제 — 코스 인덱스+상세로 대체)**
- `app/src/features/authoring/components/quizzes-screen.tsx`
- `app/src/test/authoring-quizzes-screen.test.tsx`

**app (테스트 신규)**
- `app/src/test/authoring-courses-index-screen.test.tsx`
- `app/src/test/authoring-course-quizzes-screen.test.tsx`
- `app/src/test/authoring-api.test.ts` — 코스 API 케이스 추가(기존 파일에 append)

---

## Task 1 (S1): `GET /authoring/courses` (코스 목록)

**Files:**
- Create: `server/.../authoring/dto/AuthoringCourseResponse.java`
- Create: `server/.../authoring/dto/AuthoringCourseListResponse.java`
- Create: `server/.../authoring/AuthoringCourseService.java`
- Create: `server/.../authoring/AuthoringCourseController.java`
- Test: `server/.../authoring/AuthoringCourseControllerTest.java`

**Interfaces:**
- Produces: `AuthoringCourseService.listCourses(): AuthoringCourseListResponse`; `AuthoringCourseResponse(Long courseId, String title, String category)`; `AuthoringCourseListResponse(List<AuthoringCourseResponse> courses)`; controller `GET /api/v1/authoring/courses`.
- Consumes: `CourseRepository`(기존, `findAll()`), `Course`(기존 getter: `getId/getTitle/getCategory`).

- [ ] **Step 1: DTO 2개 작성**

`AuthoringCourseResponse.java`:
```java
package studio.thumbsup.server.quiz.authoring.dto;

import studio.thumbsup.server.quiz.Course;

public record AuthoringCourseResponse(Long courseId, String title, String category) {

    public static AuthoringCourseResponse from(Course course) {
        return new AuthoringCourseResponse(course.getId(), course.getTitle(), course.getCategory());
    }
}
```

`AuthoringCourseListResponse.java`:
```java
package studio.thumbsup.server.quiz.authoring.dto;

import java.util.List;

public record AuthoringCourseListResponse(List<AuthoringCourseResponse> courses) {}
```

- [ ] **Step 2: Service 작성**

`AuthoringCourseService.java`:
```java
package studio.thumbsup.server.quiz.authoring;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.quiz.CourseRepository;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseListResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseResponse;

/**
 * 코스 인덱스·코스별 라이브 문제 상세 조회(#182). 라이브 문제의 전체 상세를 읽기 전용으로 훑는 용도라
 * draft/잡과 무관한 별도 서비스로 둔다.
 */
@Service
@Transactional(readOnly = true)
public class AuthoringCourseService {

    private final CourseRepository courseRepository;

    public AuthoringCourseService(CourseRepository courseRepository) {
        this.courseRepository = courseRepository;
    }

    public AuthoringCourseListResponse listCourses() {
        return new AuthoringCourseListResponse(
                courseRepository.findAll().stream().map(AuthoringCourseResponse::from).toList());
    }
}
```

- [ ] **Step 3: Controller 작성**

`AuthoringCourseController.java`:
```java
package studio.thumbsup.server.quiz.authoring;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseListResponse;

/**
 * 코스 인덱스·코스별 라이브 문제 상세 조회(#182). 컨트롤러는 얇게 — 호출·envelope만.
 */
@Tag(name = "Authoring Course", description = "코스별 라이브 문제 상세 조회")
@RestController
@RequestMapping("/api/v1/authoring/courses")
public class AuthoringCourseController {

    private final AuthoringCourseService courseService;

    public AuthoringCourseController(AuthoringCourseService courseService) {
        this.courseService = courseService;
    }

    @Operation(summary = "코스 목록 조회")
    @GetMapping
    public ApiResponse<AuthoringCourseListResponse> list() {
        return ApiResponse.success(courseService.listCourses());
    }
}
```

- [ ] **Step 4: 컨트롤러 테스트 작성(목록)**

`AuthoringCourseControllerTest.java`:
```java
package studio.thumbsup.server.quiz.authoring;

import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseListResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseResponse;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다. */
@ExtendWith(MockitoExtension.class)
class AuthoringCourseControllerTest {

    @Mock
    private AuthoringCourseService courseService;

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new AuthoringCourseController(courseService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
                .build();
    }

    @Test
    @DisplayName("코스 목록은 200과 courses 배열을 반환한다")
    void returns_200_with_courses() throws Exception {
        given(courseService.listCourses())
                .willReturn(new AuthoringCourseListResponse(
                        List.of(new AuthoringCourseResponse(1L, "운영체제", "CS"))));

        mockMvc.perform(get("/api/v1/authoring/courses"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.courses[0].courseId").value(1))
                .andExpect(jsonPath("$.data.courses[0].title").value("운영체제"));
    }
}
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `cd server && ./gradlew test --tests 'studio.thumbsup.server.quiz.authoring.AuthoringCourseControllerTest'`
Expected: PASS (1 test)

- [ ] **Step 6: 커밋**

```bash
git add server/src/main/java/studio/thumbsup/server/quiz/authoring/AuthoringCourseController.java \
        server/src/main/java/studio/thumbsup/server/quiz/authoring/AuthoringCourseService.java \
        server/src/main/java/studio/thumbsup/server/quiz/authoring/dto/AuthoringCourseResponse.java \
        server/src/main/java/studio/thumbsup/server/quiz/authoring/dto/AuthoringCourseListResponse.java \
        server/src/test/java/studio/thumbsup/server/quiz/authoring/AuthoringCourseControllerTest.java
git commit -m "$(cat <<'EOF'
feat(server): 코스 목록 조회 엔드포인트 (#182)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 (S2): `GET /authoring/courses/{courseId}/quizzes` (코스별 문제 전체 상세)

**Files:**
- Modify: `server/.../authoring/AuthoringErrorType.java` (에러 타입 1개 추가)
- Create: `server/.../authoring/dto/AuthoringDetailedQuizResponse.java`
- Create: `server/.../authoring/dto/AuthoringDetailedStepResponse.java`
- Create: `server/.../authoring/dto/AuthoringCourseDetailResponse.java`
- Modify: `server/.../authoring/AuthoringCourseService.java` (메서드·의존성 추가)
- Modify: `server/.../authoring/AuthoringCourseController.java` (GET 1개 추가)
- Test: `server/.../authoring/AuthoringCourseControllerTest.java` (케이스 추가)

**Interfaces:**
- Produces: `AuthoringCourseService.getCourseQuizzes(Long courseId): AuthoringCourseDetailResponse`; `AuthoringDetailedQuizResponse(Long quizId, int slotOrder, GeneratedQuizSet.GeneratedQuiz generated)`; `AuthoringDetailedStepResponse(int stepOrder, String topic, List<AuthoringDetailedQuizResponse> quizzes)`; `AuthoringCourseDetailResponse(Long courseId, String title, List<AuthoringDetailedStepResponse> steps)`; controller `GET /api/v1/authoring/courses/{courseId}/quizzes`.
- Consumes: `QuizToGeneratedQuizMapper.toGenerated(Quiz): GeneratedQuizSet.GeneratedQuiz`(기존); `QuizRepository.findAll()`(기존); `QuizStepRepository.findAll()`(기존); `Quiz.getStepOrder/getSlotOrder/getId`(기존); `QuizStep.getStepOrder/getTopic`(기존); `BusinessException`(기존).

- [ ] **Step 1: 에러 타입 추가**

`AuthoringErrorType.java` — 마지막 enum 값 뒤에 추가(기존 값들의 세미콜론 위치 조정):
```java
    AUTHORING_JOB_NOT_CLAIMABLE(HttpStatus.CONFLICT, "결과를 제출할 수 있는 상태가 아닙니다."),
    AUTHORING_COURSE_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 코스입니다.");
```

- [ ] **Step 2: DTO 3개 작성**

`AuthoringDetailedQuizResponse.java`:
```java
package studio.thumbsup.server.quiz.authoring.dto;

import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;

public record AuthoringDetailedQuizResponse(
        Long quizId, int slotOrder, GeneratedQuizSet.GeneratedQuiz generated) {}
```

`AuthoringDetailedStepResponse.java`:
```java
package studio.thumbsup.server.quiz.authoring.dto;

import java.util.List;

public record AuthoringDetailedStepResponse(
        int stepOrder, String topic, List<AuthoringDetailedQuizResponse> quizzes) {}
```

`AuthoringCourseDetailResponse.java`:
```java
package studio.thumbsup.server.quiz.authoring.dto;

import java.util.List;

public record AuthoringCourseDetailResponse(
        Long courseId, String title, List<AuthoringDetailedStepResponse> steps) {}
```

- [ ] **Step 3: Service에 상세 조회 추가**

`AuthoringCourseService.java` — import·필드·메서드 추가(기존 `listCourses` 유지):
```java
package studio.thumbsup.server.quiz.authoring;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.Course;
import studio.thumbsup.server.quiz.CourseRepository;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseListResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringDetailedQuizResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringDetailedStepResponse;

@Service
@Transactional(readOnly = true)
public class AuthoringCourseService {

    private final CourseRepository courseRepository;
    private final QuizRepository quizRepository;
    private final QuizStepRepository quizStepRepository;

    public AuthoringCourseService(
            CourseRepository courseRepository,
            QuizRepository quizRepository,
            QuizStepRepository quizStepRepository) {
        this.courseRepository = courseRepository;
        this.quizRepository = quizRepository;
        this.quizStepRepository = quizStepRepository;
    }

    public AuthoringCourseListResponse listCourses() {
        return new AuthoringCourseListResponse(
                courseRepository.findAll().stream().map(AuthoringCourseResponse::from).toList());
    }

    public AuthoringCourseDetailResponse getCourseQuizzes(Long courseId) {
        Course course = courseRepository
                .findById(courseId)
                .orElseThrow(() -> new BusinessException(AuthoringErrorType.AUTHORING_COURSE_NOT_FOUND));

        Map<Integer, String> topicByStepOrder = quizStepRepository.findAll().stream()
                .collect(Collectors.toMap(QuizStep::getStepOrder, QuizStep::getTopic));

        // quiz_step에 course FK가 아직 없어 지금은 모든 스텝을 반환한다(코스 1개 전제).
        // FK 도입 시 여기서 courseId로 스텝을 필터한다(#182 forward-compat seam).
        Map<Integer, List<Quiz>> quizzesByStep = quizRepository.findAll().stream()
                .filter(quiz -> quiz.getStepOrder() > 0) // 0은 "스텝 밖" placeholder sentinel
                .sorted(Comparator.comparingInt(Quiz::getStepOrder).thenComparingInt(Quiz::getSlotOrder))
                .collect(Collectors.groupingBy(Quiz::getStepOrder, LinkedHashMap::new, Collectors.toList()));

        List<AuthoringDetailedStepResponse> steps = quizzesByStep.entrySet().stream()
                .map(entry -> toDetailedStep(entry.getKey(), entry.getValue(), topicByStepOrder))
                .toList();
        return new AuthoringCourseDetailResponse(course.getId(), course.getTitle(), steps);
    }

    private AuthoringDetailedStepResponse toDetailedStep(
            int stepOrder, List<Quiz> quizzes, Map<Integer, String> topicByStepOrder) {
        String topic = Optional.ofNullable(topicByStepOrder.get(stepOrder)).orElse(null);
        List<AuthoringDetailedQuizResponse> detailed = quizzes.stream()
                .map(quiz -> new AuthoringDetailedQuizResponse(
                        quiz.getId(), quiz.getSlotOrder(), QuizToGeneratedQuizMapper.toGenerated(quiz)))
                .toList();
        return new AuthoringDetailedStepResponse(stepOrder, topic, detailed);
    }
}
```

- [ ] **Step 4: Controller에 상세 GET 추가**

`AuthoringCourseController.java` — import·메서드 추가:
```java
import org.springframework.web.bind.annotation.PathVariable;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseDetailResponse;
```
```java
    @Operation(summary = "코스별 라이브 문제를 스텝별로 그룹핑해 전체 상세와 함께 조회")
    @GetMapping("/{courseId}/quizzes")
    public ApiResponse<AuthoringCourseDetailResponse> quizzes(@PathVariable Long courseId) {
        return ApiResponse.success(courseService.getCourseQuizzes(courseId));
    }
```

- [ ] **Step 5: 컨트롤러 테스트 케이스 추가(상세 성공 + 404)**

`AuthoringCourseControllerTest.java` — import·헬퍼·테스트 추가:
```java
import static org.mockito.BDDMockito.willThrow;
import java.util.Collections;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizType;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringDetailedQuizResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringDetailedStepResponse;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;
```
```java
    @Test
    @DisplayName("코스 상세는 200과 스텝·문제 전체 상세(generated)를 반환한다")
    void returns_200_with_detailed_quizzes() throws Exception {
        GeneratedQuizSet.GeneratedQuiz generated = new GeneratedQuizSet.GeneratedQuiz(
                QuizType.OX,
                QuizDifficulty.EASY,
                "커널은 특권 수준에서 실행된다.",
                null,
                "커널은 하드웨어 자원을 관리한다.",
                null,
                "사용자 모드와 혼동하면 안 된다.",
                "O",
                null,
                null,
                Collections.emptyList(),
                Collections.emptyList(),
                List.of(new GeneratedQuizSet.GeneratedKeyword("커널", "OS의 핵심")));
        AuthoringDetailedQuizResponse quiz = new AuthoringDetailedQuizResponse(101L, 1, generated);
        AuthoringDetailedStepResponse step = new AuthoringDetailedStepResponse(1, "OS 개요", List.of(quiz));
        given(courseService.getCourseQuizzes(1L))
                .willReturn(new AuthoringCourseDetailResponse(1L, "운영체제", List.of(step)));

        mockMvc.perform(get("/api/v1/authoring/courses/1/quizzes"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("운영체제"))
                .andExpect(jsonPath("$.data.steps[0].quizzes[0].quizId").value(101))
                .andExpect(jsonPath("$.data.steps[0].quizzes[0].generated.questionText")
                        .value("커널은 특권 수준에서 실행된다."))
                .andExpect(jsonPath("$.data.steps[0].quizzes[0].generated.correctAnswer").value("O"))
                .andExpect(jsonPath("$.data.steps[0].quizzes[0].generated.keywords[0].keyword").value("커널"));
    }

    @Test
    @DisplayName("없는 코스는 404 AUTHORING_COURSE_NOT_FOUND를 반환한다")
    void returns_404_when_course_not_found() throws Exception {
        willThrow(new BusinessException(AuthoringErrorType.AUTHORING_COURSE_NOT_FOUND))
                .given(courseService)
                .getCourseQuizzes(999L);

        mockMvc.perform(get("/api/v1/authoring/courses/999/quizzes"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("AUTHORING_COURSE_NOT_FOUND"));
    }
```

- [ ] **Step 6: 테스트 실행 → 통과 확인**

Run: `cd server && ./gradlew test --tests 'studio.thumbsup.server.quiz.authoring.AuthoringCourseControllerTest'`
Expected: PASS (3 tests)

- [ ] **Step 7: 서버 전체 빌드로 회귀 확인**

Run: `cd server && ./gradlew build`
Expected: BUILD SUCCESSFUL (ArchUnit·기존 테스트 포함)

- [ ] **Step 8: 커밋**

```bash
git add server/src/main/java/studio/thumbsup/server/quiz/authoring/AuthoringErrorType.java \
        server/src/main/java/studio/thumbsup/server/quiz/authoring/AuthoringCourseController.java \
        server/src/main/java/studio/thumbsup/server/quiz/authoring/AuthoringCourseService.java \
        server/src/main/java/studio/thumbsup/server/quiz/authoring/dto/AuthoringDetailedQuizResponse.java \
        server/src/main/java/studio/thumbsup/server/quiz/authoring/dto/AuthoringDetailedStepResponse.java \
        server/src/main/java/studio/thumbsup/server/quiz/authoring/dto/AuthoringCourseDetailResponse.java \
        server/src/test/java/studio/thumbsup/server/quiz/authoring/AuthoringCourseControllerTest.java
git commit -m "$(cat <<'EOF'
feat(server): 코스별 라이브 문제 전체 상세 조회 엔드포인트 (#182)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 (A1): `QuizDetailCard` 추출 (리팩토링, 동작 불변)

**Files:**
- Create: `app/src/features/authoring/components/quiz-detail-card.tsx`
- Modify: `app/src/features/authoring/components/draft-detail-screen.tsx`

**Interfaces:**
- Produces: `QuizDetailCard({ quiz: GeneratedQuiz, slotOrder: number }): JSX` (export).
- Consumes: 기존 `GeneratedQuiz`/`GeneratedFollowUpQuestion`/`GeneratedQuizKeyword` 타입, `Card`/`Chip`.

- [ ] **Step 1: 추출 파일 생성**

`quiz-detail-card.tsx` — `draft-detail-screen.tsx`의 `QuizPayloadCard`(→`QuizDetailCard`로 이름만 변경)·`FollowUpQuestionItem`·`ExplanationBlock`·`KeywordDictionary`를 **그대로** 옮긴다. 마크업·로직·클래스 변경 금지.
```tsx
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import type {
  GeneratedFollowUpQuestion,
  GeneratedQuiz,
  GeneratedQuizKeyword,
} from "@/features/authoring/types";

/** 라이브/draft 문제의 전체 상세 렌더러 — 선택지·정답·해설·키워드·꼬리질문. */
export function QuizDetailCard({ quiz, slotOrder }: { quiz: GeneratedQuiz; slotOrder: number }) {
  // draft-detail-screen.tsx의 QuizPayloadCard 본문을 그대로 이동
  // (return (<Card ...> ... </Card>) 전체)
}

function FollowUpQuestionItem({ followUp }: { followUp: GeneratedFollowUpQuestion }) {
  // 그대로 이동
}

function ExplanationBlock({ label, text }: { label: string; text: string }) {
  // 그대로 이동
}

function KeywordDictionary({ keywords }: { keywords: GeneratedQuizKeyword[] }) {
  // 그대로 이동
}
```

> 실제 본문은 `draft-detail-screen.tsx:149-289`의 4개 함수를 잘라 붙인다. `QuizPayloadCard` → `QuizDetailCard`로만 리네임.

- [ ] **Step 2: draft-detail-screen.tsx에서 제거 + import**

`draft-detail-screen.tsx`:
- `QuizPayloadCard`·`FollowUpQuestionItem`·`ExplanationBlock`·`KeywordDictionary` 4개 함수 정의 삭제.
- 상단에 import 추가: `import { QuizDetailCard } from "@/features/authoring/components/quiz-detail-card";`
- 렌더 부분 교체: `<QuizPayloadCard ... />` → `<QuizDetailCard key={...} quiz={quiz} slotOrder={index + 1} />`
- 이제 안 쓰는 타입 import 정리: `GeneratedFollowUpQuestion`, `GeneratedQuizKeyword`는 draft-detail에서 미사용이면 import에서 제거(`GeneratedQuiz`는 여전히 `DraftDetail` 타입에 필요하면 유지, 아니면 제거). `Chip`은 헤더에서 계속 쓰므로 유지.

- [ ] **Step 3: 기존 draft-detail 테스트로 회귀 확인**

Run: `cd app && pnpm vitest run src/test/authoring-draft-detail.test.tsx`
Expected: PASS (동작 불변 — 렌더 결과 동일)

- [ ] **Step 4: lint/typecheck로 orphan import 확인**

Run: `cd app && pnpm typecheck && pnpm lint`
Expected: PASS (미사용 import 없음)

- [ ] **Step 5: 커밋**

```bash
git add app/src/features/authoring/components/quiz-detail-card.tsx \
        app/src/features/authoring/components/draft-detail-screen.tsx
git commit -m "$(cat <<'EOF'
refactor(app): 문제 상세 렌더러 QuizDetailCard 추출 (#182)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4 (A2): 코스 타입 + API 클라이언트

**Files:**
- Modify: `app/src/features/authoring/types.ts`
- Modify: `app/src/features/authoring/api.ts`
- Test: `app/src/test/authoring-api.test.ts` (케이스 추가)

**Interfaces:**
- Produces: `AuthoringCourse`, `AuthoringDetailedQuiz`, `AuthoringDetailedStep`, `AuthoringCourseDetail`; `getAuthoringCourses(): Promise<AuthoringCourse[]>`; `getAuthoringCourseQuizzes(courseId: number): Promise<AuthoringCourseDetail>`.
- Consumes: 기존 `GeneratedQuiz` 타입, `apiRequest`.

- [ ] **Step 1: 타입 추가**

`types.ts` — 파일 끝에 추가:
```ts
export type AuthoringCourse = { courseId: number; title: string; category: string };

export type AuthoringDetailedQuiz = {
  quizId: number;
  slotOrder: number;
  generated: GeneratedQuiz;
};

export type AuthoringDetailedStep = {
  stepOrder: number;
  topic: string | null;
  quizzes: AuthoringDetailedQuiz[];
};

export type AuthoringCourseDetail = {
  courseId: number;
  title: string;
  steps: AuthoringDetailedStep[];
};
```

- [ ] **Step 2: API 함수 추가**

`api.ts` — import에 타입 추가하고 함수 추가:
```ts
import type {
  AuthoringCourse,
  AuthoringCourseDetail,
  AuthoringStep,
  DraftDetail,
  DraftSummary,
  JobStatus,
} from "./types";
```
```ts
export async function getAuthoringCourses(): Promise<AuthoringCourse[]> {
  const data = await apiRequest<{ courses: AuthoringCourse[] }>("/authoring/courses");
  return data.courses;
}

export function getAuthoringCourseQuizzes(courseId: number): Promise<AuthoringCourseDetail> {
  return apiRequest(`/authoring/courses/${courseId}/quizzes`);
}
```

- [ ] **Step 3: API 테스트 추가**

`authoring-api.test.ts` — import에 새 함수 추가하고 `describe` 안에 케이스 추가:
```ts
  it("getAuthoringCourses가 courses 배열을 언랩한다", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(200, envelope("SUCCESS", { courses: [{ courseId: 1, title: "운영체제", category: "CS" }] })),
    );
    vi.stubGlobal("fetch", fetchMock);

    const result = await getAuthoringCourses();

    expect(result).toEqual([{ courseId: 1, title: "운영체제", category: "CS" }]);
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/courses",
    );
  });

  it("getAuthoringCourseQuizzes가 courseId 경로로 상세를 반환한다", async () => {
    const detail = { courseId: 1, title: "운영체제", steps: [] };
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse(200, envelope("SUCCESS", detail)));
    vi.stubGlobal("fetch", fetchMock);

    const result = await getAuthoringCourseQuizzes(1);

    expect(result).toEqual(detail);
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/courses/1/quizzes",
    );
  });
```
(파일 상단 import에 `getAuthoringCourses, getAuthoringCourseQuizzes` 추가.)

- [ ] **Step 4: 테스트 실행 → 통과**

Run: `cd app && pnpm vitest run src/test/authoring-api.test.ts`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add app/src/features/authoring/types.ts app/src/features/authoring/api.ts app/src/test/authoring-api.test.ts
git commit -m "$(cat <<'EOF'
feat(app): 코스 조회 타입·API 클라이언트 (#182)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5 (A3): 코스 인덱스 화면 (기존 요약 탭 대체)

**Files:**
- Create: `app/src/features/authoring/components/courses-index-screen.tsx`
- Modify: `app/src/app/authoring/quizzes/page.tsx`
- Delete: `app/src/features/authoring/components/quizzes-screen.tsx`
- Delete: `app/src/test/authoring-quizzes-screen.test.tsx`
- Test: `app/src/test/authoring-courses-index-screen.test.tsx`

**Interfaces:**
- Produces: `CoursesIndexScreen(): JSX`.
- Consumes: `getAuthoringCourses`(A2), `AuthoringCourse`(A2), `Card`/`Chip`/`EmptyState`/`Feedback`/`Skeleton`, `Link`, `useRouter`, `ApiError`.

- [ ] **Step 1: 대체 대상 참조 확인(삭제 안전성)**

Run: `cd app && grep -rn "quizzes-screen\|QuizzesScreen" src`
Expected: `quizzes/page.tsx`·`quizzes-screen.tsx`·`authoring-quizzes-screen.test.tsx`만 나옴(그 외 소비처 없음 확인).

- [ ] **Step 2: CoursesIndexScreen 작성**

`courses-index-screen.tsx`:
```tsx
"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import { EmptyState } from "@/components/ui/empty-state";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import { getAuthoringCourses } from "@/features/authoring/api";
import type { AuthoringCourse } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";

type LoadState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "success"; courses: AuthoringCourse[] };

/** 코스 인덱스 — 라이브 문제를 코스 단위로 진입하는 목록. 코스 클릭 시 상세로 이동. */
export function CoursesIndexScreen() {
  const router = useRouter();
  const [state, setState] = useState<LoadState>({ status: "loading" });

  const load = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const courses = await getAuthoringCourses();
      setState({ status: "success", courses });
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        router.replace("/login");
        return;
      }
      if (error instanceof ApiError && error.status === 403) {
        router.replace("/");
        return;
      }
      setState({ status: "error" });
    }
  }, [router]);

  useEffect(() => {
    void load();
  }, [load]);

  if (state.status === "loading") {
    return <CoursesSkeleton />;
  }
  if (state.status === "error") {
    return (
      <Feedback onRetry={() => void load()} tone="error">
        코스를 불러오지 못했어요.
      </Feedback>
    );
  }
  if (state.courses.length === 0) {
    return <EmptyState description="아직 등록된 코스가 없어요." title="등록된 코스가 없어요" />;
  }

  return (
    <ul className="flex flex-col gap-3">
      {state.courses.map((course) => (
        <li key={course.courseId}>
          <Link className="block" href={`/authoring/quizzes/${course.courseId}`}>
            <Card className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <span className="text-base font-bold text-ink">{course.title}</span>
                <Chip tone="neutral">{course.category}</Chip>
              </div>
              <span aria-hidden className="text-ink-muted">
                →
              </span>
            </Card>
          </Link>
        </li>
      ))}
    </ul>
  );
}

function CoursesSkeleton() {
  return (
    <div className="flex flex-col gap-3">
      {[0, 1, 2].map((row) => (
        <Skeleton className="h-16 w-full" key={row} />
      ))}
    </div>
  );
}
```

- [ ] **Step 3: page.tsx 교체**

`app/src/app/authoring/quizzes/page.tsx`:
```tsx
import { RequireAuth } from "@/features/auth/require-auth";
import { CoursesIndexScreen } from "@/features/authoring/components/courses-index-screen";

export const dynamic = "force-dynamic";

export default function AuthoringQuizzesPage() {
  return (
    <RequireAuth>
      <CoursesIndexScreen />
    </RequireAuth>
  );
}
```

- [ ] **Step 4: 대체된 요약 화면·테스트 삭제**

```bash
git rm app/src/features/authoring/components/quizzes-screen.tsx \
       app/src/test/authoring-quizzes-screen.test.tsx
```

- [ ] **Step 5: 인덱스 화면 테스트 작성**

`authoring-courses-index-screen.test.tsx`:
```tsx
import { render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { CoursesIndexScreen } from "@/features/authoring/components/courses-index-screen";
import type { AuthoringCourse } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";

const { getAuthoringCoursesMock, mockRouter } = vi.hoisted(() => ({
  getAuthoringCoursesMock: vi.fn(),
  mockRouter: { push: vi.fn(), replace: vi.fn() },
}));

vi.mock("@/features/authoring/api", () => ({ getAuthoringCourses: getAuthoringCoursesMock }));
vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));

const COURSES: AuthoringCourse[] = [{ courseId: 1, title: "운영체제", category: "CS" }];

beforeEach(() => {
  getAuthoringCoursesMock.mockReset();
  mockRouter.replace.mockReset();
});

describe("CoursesIndexScreen", () => {
  it("코스 카드를 렌더하고 상세 경로로 링크한다", async () => {
    getAuthoringCoursesMock.mockResolvedValue(COURSES);

    render(<CoursesIndexScreen />);

    const link = await screen.findByRole("link", { name: /운영체제/ });
    expect(link).toHaveAttribute("href", "/authoring/quizzes/1");
  });

  it("코스가 없으면 빈 상태를 보여준다", async () => {
    getAuthoringCoursesMock.mockResolvedValue([]);

    render(<CoursesIndexScreen />);

    expect(await screen.findByText("등록된 코스가 없어요")).toBeInTheDocument();
  });

  it("세션 만료(401)면 로그인으로 이동한다", async () => {
    getAuthoringCoursesMock.mockRejectedValue(
      new ApiError({ code: "UNAUTHORIZED", status: 401, message: "unauthorized" }),
    );

    render(<CoursesIndexScreen />);

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/login"));
  });

  it("권한 없음(403)이면 홈으로 이동한다", async () => {
    getAuthoringCoursesMock.mockRejectedValue(
      new ApiError({ code: "FORBIDDEN", status: 403, message: "forbidden" }),
    );

    render(<CoursesIndexScreen />);

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/"));
  });
});
```

- [ ] **Step 6: 테스트 실행 → 통과**

Run: `cd app && pnpm vitest run src/test/authoring-courses-index-screen.test.tsx`
Expected: PASS (4 tests)

- [ ] **Step 7: 커밋**

```bash
git add app/src/features/authoring/components/courses-index-screen.tsx \
        app/src/app/authoring/quizzes/page.tsx \
        app/src/test/authoring-courses-index-screen.test.tsx
git commit -m "$(cat <<'EOF'
feat(app): 라이브 문제 탭을 코스 인덱스로 전환 (#182)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6 (A4): 코스 상세 화면 (3단 아코디언) + 라우트

**Files:**
- Create: `app/src/features/authoring/components/course-quizzes-screen.tsx`
- Create: `app/src/app/authoring/quizzes/[course]/page.tsx`
- Test: `app/src/test/authoring-course-quizzes-screen.test.tsx`

**Interfaces:**
- Produces: `CourseQuizzesScreen({ courseId: number }): JSX`; route `/authoring/quizzes/[course]`.
- Consumes: `getAuthoringCourseQuizzes`(A2), `AuthoringCourseDetail`(A2), `QuizDetailCard`(A1), `ImproveSheet`(기존), `Button`/`Chip`/`EmptyState`/`Feedback`/`Skeleton`, `ApiError`, `RequireAuth`(기존).

- [ ] **Step 1: CourseQuizzesScreen 작성**

`course-quizzes-screen.tsx`:
```tsx
"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Chip } from "@/components/ui/chip";
import { EmptyState } from "@/components/ui/empty-state";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import { getAuthoringCourseQuizzes } from "@/features/authoring/api";
import { ImproveSheet } from "@/features/authoring/components/improve-sheet";
import { QuizDetailCard } from "@/features/authoring/components/quiz-detail-card";
import type { AuthoringCourseDetail } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";

type LoadState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "success"; detail: AuthoringCourseDetail };

/** 코스 상세 — 스텝(아코디언) → 문제 요약 행 → 클릭 시 전체 상세. 초기 전체 접힘. */
export function CourseQuizzesScreen({ courseId }: { courseId: number }) {
  const router = useRouter();
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [openSteps, setOpenSteps] = useState<Set<number>>(new Set());
  const [openQuizzes, setOpenQuizzes] = useState<Set<number>>(new Set());
  const [improvingQuizId, setImprovingQuizId] = useState<number | null>(null);

  const load = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const detail = await getAuthoringCourseQuizzes(courseId);
      setState({ status: "success", detail });
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        router.replace("/login");
        return;
      }
      if (error instanceof ApiError && error.status === 403) {
        router.replace("/");
        return;
      }
      setState({ status: "error" });
    }
  }, [courseId, router]);

  useEffect(() => {
    void load();
  }, [load]);

  const toggleStep = (stepOrder: number) => {
    setOpenSteps((prev) => {
      const next = new Set(prev);
      if (next.has(stepOrder)) {
        next.delete(stepOrder);
      } else {
        next.add(stepOrder);
      }
      return next;
    });
  };

  const toggleQuiz = (quizId: number) => {
    setOpenQuizzes((prev) => {
      const next = new Set(prev);
      if (next.has(quizId)) {
        next.delete(quizId);
      } else {
        next.add(quizId);
      }
      return next;
    });
  };

  if (state.status === "loading") {
    return <CourseSkeleton />;
  }
  if (state.status === "error") {
    return (
      <Feedback onRetry={() => void load()} tone="error">
        문제를 불러오지 못했어요.
      </Feedback>
    );
  }

  const { detail } = state;
  if (detail.steps.length === 0) {
    return <EmptyState description="아직 등록된 문제가 없어요." title="등록된 문제가 없어요" />;
  }

  return (
    <div className="flex flex-col gap-6">
      <h2 className="text-xl font-bold text-ink">{detail.title}</h2>

      <div className="flex flex-col gap-3">
        {detail.steps.map((step) => {
          const stepOpen = openSteps.has(step.stepOrder);
          return (
            <section className="flex flex-col gap-2" key={step.stepOrder}>
              <button
                aria-expanded={stepOpen}
                className="flex items-center justify-between gap-3 rounded-control bg-surface-muted px-4 py-3 text-left"
                onClick={() => toggleStep(step.stepOrder)}
                type="button"
              >
                <span className="text-base font-bold text-ink">
                  STEP {step.stepOrder} · {step.topic ?? "제목 없음"}
                </span>
                <span className="text-sm text-ink-muted">
                  문제 {step.quizzes.length}개 {stepOpen ? "▲" : "▼"}
                </span>
              </button>

              {stepOpen ? (
                <ul className="flex flex-col gap-2">
                  {step.quizzes.map((quiz) => {
                    const quizOpen = openQuizzes.has(quiz.quizId);
                    return (
                      <li key={quiz.quizId}>
                        <button
                          aria-expanded={quizOpen}
                          className="flex w-full items-center gap-2 rounded-control border border-border px-3 py-2 text-left"
                          onClick={() => toggleQuiz(quiz.quizId)}
                          type="button"
                        >
                          <Chip tone="neutral">{quiz.generated.type}</Chip>
                          <Chip tone="neutral">{quiz.generated.difficulty}</Chip>
                          <span className="min-w-0 flex-1 truncate text-sm text-ink">
                            {quiz.generated.questionText}
                          </span>
                          <span className="text-ink-muted text-xs">{quizOpen ? "▲" : "▼"}</span>
                        </button>

                        {quizOpen ? (
                          <div className="mt-2 flex flex-col gap-3">
                            <QuizDetailCard quiz={quiz.generated} slotOrder={quiz.slotOrder} />
                            <div>
                              <Button
                                onClick={() => setImprovingQuizId(quiz.quizId)}
                                variant="secondary"
                              >
                                개선
                              </Button>
                            </div>
                          </div>
                        ) : null}
                      </li>
                    );
                  })}
                </ul>
              ) : null}
            </section>
          );
        })}
      </div>

      <ImproveSheet
        onClose={() => setImprovingQuizId(null)}
        open={improvingQuizId !== null}
        quizId={improvingQuizId}
      />
    </div>
  );
}

function CourseSkeleton() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-7 w-40" />
      {[0, 1, 2].map((row) => (
        <Skeleton className="h-14 w-full" key={row} />
      ))}
    </div>
  );
}
```

- [ ] **Step 2: 라우트 page.tsx 작성**

`app/src/app/authoring/quizzes/[course]/page.tsx`:
```tsx
import { redirect } from "next/navigation";
import { RequireAuth } from "@/features/auth/require-auth";
import { CourseQuizzesScreen } from "@/features/authoring/components/course-quizzes-screen";

export const dynamic = "force-dynamic";

type CourseRouteProps = {
  params: Promise<{ course: string }>;
};

export default async function AuthoringCoursePage({ params }: CourseRouteProps) {
  const { course } = await params;
  const courseId = Number(course);

  // 잘못된 course id로 직접 진입하면 코스 인덱스로 돌려보낸다(방어).
  if (!Number.isInteger(courseId) || courseId <= 0) {
    redirect("/authoring/quizzes");
  }

  return (
    <RequireAuth>
      <CourseQuizzesScreen courseId={courseId} />
    </RequireAuth>
  );
}
```

- [ ] **Step 3: 상세 화면 테스트 작성**

`authoring-course-quizzes-screen.test.tsx`:
```tsx
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { CourseQuizzesScreen } from "@/features/authoring/components/course-quizzes-screen";
import type { AuthoringCourseDetail } from "@/features/authoring/types";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { getCourseQuizzesMock, improveQuizMock, mockRouter } = vi.hoisted(() => ({
  getCourseQuizzesMock: vi.fn(),
  improveQuizMock: vi.fn(),
  mockRouter: { push: vi.fn(), replace: vi.fn() },
}));

vi.mock("@/features/authoring/api", () => ({
  getAuthoringCourseQuizzes: getCourseQuizzesMock,
  improveQuiz: improveQuizMock,
}));
vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));

const DETAIL: AuthoringCourseDetail = {
  courseId: 1,
  title: "운영체제",
  steps: [
    {
      stepOrder: 1,
      topic: "OS 개요",
      quizzes: [
        {
          quizId: 101,
          slotOrder: 1,
          generated: {
            type: "OX",
            difficulty: "EASY",
            questionText: "커널은 특권 수준에서 실행된다.",
            codeSnippet: null,
            explanationSummary: "커널은 하드웨어 자원을 관리한다.",
            explanationExample: null,
            wrongAnswerExplanation: "사용자 모드와 혼동 금지.",
            correctAnswer: "O",
            choices: null,
            answerKeywords: null,
            followUpQuestions: [
              {
                content: "시스템 콜이란?",
                isPrimary: true,
                difficulty: "MEDIUM",
                oneLineAnswer: "OS 기능 요청 인터페이스",
                blocks: [{ label: "정의", content: "응용이 커널 기능을 부르는 통로" }],
                keywords: [{ keyword: "트랩", description: "소프트웨어 인터럽트" }],
              },
            ],
            derivedConcepts: null,
            keywords: [{ keyword: "커널", description: "OS의 핵심" }],
          },
        },
      ],
    },
  ],
};

function renderScreen() {
  render(
    <AppToastProvider>
      <CourseQuizzesScreen courseId={1} />
    </AppToastProvider>,
  );
}

beforeEach(() => {
  getCourseQuizzesMock.mockReset();
  improveQuizMock.mockReset();
  mockRouter.push.mockReset();
});

describe("CourseQuizzesScreen", () => {
  it("초기에는 스텝이 접혀 있어 문제 텍스트가 보이지 않는다", async () => {
    getCourseQuizzesMock.mockResolvedValue(DETAIL);

    renderScreen();

    expect(await screen.findByText(/STEP 1 · OS 개요/)).toBeInTheDocument();
    expect(screen.queryByText("커널은 특권 수준에서 실행된다.")).not.toBeInTheDocument();
  });

  it("스텝 클릭 → 문제 행, 문제 클릭 → 키워드·해설·꼬리질문 전체 상세가 보인다", async () => {
    getCourseQuizzesMock.mockResolvedValue(DETAIL);

    renderScreen();
    fireEvent.click(await screen.findByRole("button", { name: /STEP 1/ }));

    const quizRow = await screen.findByRole("button", { name: /커널은 특권 수준에서 실행된다\./ });
    fireEvent.click(quizRow);

    expect(await screen.findByText("커널")).toBeInTheDocument(); // 키워드 사전
    expect(screen.getByText("커널은 하드웨어 자원을 관리한다.")).toBeInTheDocument(); // 해설 요약
    expect(screen.getByText(/꼬리질문 1개/)).toBeInTheDocument(); // 꼬리질문 disclosure
    expect(screen.getByText("정답: O")).toBeInTheDocument();
  });

  it("문제 상세의 개선 버튼으로 개선 시트를 연다", async () => {
    getCourseQuizzesMock.mockResolvedValue(DETAIL);

    renderScreen();
    fireEvent.click(await screen.findByRole("button", { name: /STEP 1/ }));
    fireEvent.click(await screen.findByRole("button", { name: /커널은 특권 수준/ }));
    fireEvent.click(screen.getByRole("button", { name: "개선" }));

    expect(await screen.findByLabelText("개선 지시")).toBeInTheDocument();
  });
});
```

- [ ] **Step 4: 테스트 실행 → 통과**

Run: `cd app && pnpm vitest run src/test/authoring-course-quizzes-screen.test.tsx`
Expected: PASS (3 tests)

- [ ] **Step 5: 커밋**

```bash
git add app/src/features/authoring/components/course-quizzes-screen.tsx \
        app/src/app/authoring/quizzes/\[course\]/page.tsx \
        app/src/test/authoring-course-quizzes-screen.test.tsx
git commit -m "$(cat <<'EOF'
feat(app): 코스 상세 3단 아코디언 문제 열람 화면 (#182)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7 (V): 전체 게이트 검증 + 로컬 풀스택 핸드오프

**Files:** 없음(검증만).

- [ ] **Step 1: app 검증 게이트 (verify-app)**

Run: `cd app && pnpm typecheck && pnpm lint && pnpm build && pnpm check:design`
Expected: 전부 통과. (실패 시 해당 Task로 돌아가 수정.)

- [ ] **Step 2: 서버 빌드**

Run: `cd server && ./gradlew build`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: 로컬 풀스택 스모크 (사용자 수행)**

`authoring` 스킬 / `thumbsup-local-fullstack-test` 메모리 절차로 server+MySQL+app을 로컬 기동하고, ADMIN 계정으로 `/authoring/quizzes` → 코스 클릭 → 스텝 펼침 → 문제 클릭 → 키워드·해설·꼬리질문 노출 → 개선 진입까지 클릭 검증. (사용자가 직접 수행 후 PR 생성 예정.)

- [ ] **Step 4: PR (`pr` 스킬)**

`pr` 스킬로 PR 생성. 본문에 `Closes #182`. Squash merge. server 변경 포함이므로 `build-and-test`·`gitleaks` 체크 통과 확인.

---

## Self-Review

**Spec coverage** (스펙 §별 → Task):
- §4 서버 엔드포인트 2개 → S1(courses), S2(courses/{id}/quizzes) ✓. ADMIN 게이트 = 기존 `/authoring/**` 매처 자동 적용(수정 없음) ✓. 404 seam → S2 ✓. 다중 코스 seam 주석 → S2 Step 3 ✓.
- §5.2 QuizDetailCard 추출 → A1 ✓.
- §5.3 CoursesIndexScreen + 탭 전환 → A3 ✓.
- §5.4 3단 아코디언 상세 + 개선 유지 → A4 ✓.
- §5.5 타입/API → A2 ✓.
- §7 완료 기준(verify-app + gradlew build) → V ✓.

**Placeholder scan:** A1 Step 1의 "본문 그대로 이동"은 실제 원본 위치(`draft-detail-screen.tsx:149-289`)를 명시했으므로 실행 가능한 지시(리팩토링 이동은 원본 복붙이 정확). 그 외 코드 스텝은 전체 코드 포함 ✓.

**Type consistency:**
- 서버 `AuthoringDetailedQuizResponse(quizId, slotOrder, generated)` ↔ app `AuthoringDetailedQuiz(quizId, slotOrder, generated)` ✓.
- 서버 `generated: GeneratedQuizSet.GeneratedQuiz`(13필드) ↔ app `GeneratedQuiz`(13필드, 이름 일치) ✓ — enum type/difficulty는 Jackson이 이름 문자열로 직렬화, app에선 string.
- `getCourseQuizzes(Long)` ↔ 컨트롤러 `@PathVariable Long courseId` ↔ app `getAuthoringCourseQuizzes(courseId: number)` → 경로 `/authoring/courses/${courseId}/quizzes` ✓.
- `QuizDetailCard({ quiz, slotOrder })` — A1 정의 ↔ A4 사용 시그니처 일치 ✓.
