package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.DatabaseCleanUp;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture;
import studio.thumbsup.server.quiz.generation.QuizPreset;

@SpringBootTest
@Testcontainers
@ActiveProfiles("test")
class AuthoringPublishIntegrationTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    @Autowired
    private AuthoringPublishService publishService;

    @Autowired
    private AuthoringOutlineRepository outlineRepository;

    @Autowired
    private AuthoringOutlineStepRepository stepRepository;

    @Autowired
    private QuizDraftRepository draftRepository;

    @Autowired
    private CourseRepository courseRepository;

    @Autowired
    private QuizStepRepository quizStepRepository;

    @Autowired
    private QuizRepository quizRepository;

    @Autowired
    private DatabaseCleanUp databaseCleanUp;

    @BeforeEach
    void cleanData() {
        databaseCleanUp.execute();
    }

    @Test
    @DisplayName("전부 승인된 뼈대를 발행하면 코스·스텝·문제가 한꺼번에 생긴다")
    void publishesWholeCourse() {
        AuthoringOutline outline = prepareOutline(3, QuizPreset.BASIC_5, Set.of(), -1);

        var response = publishService.publish(7L, outline.getId());

        assertThat(response.stepCount()).isEqualTo(3);
        assertThat(courseRepository.findAllByOrderByIdAsc()).hasSize(1);
        assertThat(quizStepRepository.findAll())
                .extracting(QuizStep::getStepOrder)
                .containsExactly(1, 2, 3);
        assertThat(quizStepRepository.findAll())
                .allSatisfy(step -> assertThat(step.getEstimatedMinutes()).isEqualTo(3));
        assertThat(quizRepository.count()).isEqualTo(15);
        AuthoringOutline published = outlineRepository.findById(outline.getId()).orElseThrow();
        assertThat(published.getStatus()).isEqualTo(AuthoringOutlineStatus.PUBLISHED);
        assertThat(published.getPublishedCourseId()).isEqualTo(response.courseId());
    }

    @Test
    @DisplayName("발행 전에는 학습자 읽기 경로에 코스가 없다")
    void invisibleBeforePublish() {
        prepareOutline(3, QuizPreset.BASIC_5, Set.of(), -1);

        assertThat(courseRepository.findAllByOrderByIdAsc()).isEmpty();
    }

    @Test
    @DisplayName("미승인 스텝이 하나라도 있으면 409이고 아무것도 쓰이지 않는다")
    void rejectsWhenAnyStepUnapproved() {
        AuthoringOutline outline = prepareOutline(3, QuizPreset.BASIC_5, Set.of(2), -1);

        assertThatThrownBy(() -> publishService.publish(7L, outline.getId()))
                .isInstanceOf(BusinessException.class)
                .extracting(exception -> ((BusinessException) exception).getErrorType())
                .isEqualTo(AuthoringErrorType.AUTHORING_OUTLINE_NOT_READY);
        assertThat(courseRepository.count()).isZero();
        assertThat(quizStepRepository.count()).isZero();
    }

    @Test
    @DisplayName("스텝이 0개인 뼈대는 409다")
    void rejectsEmptyOutline() {
        AuthoringOutline outline = outlineRepository.saveAndFlush(AuthoringOutline.create("빈 코스", "CS", "", 7L));

        assertThatThrownBy(() -> publishService.publish(7L, outline.getId()))
                .isInstanceOf(BusinessException.class)
                .extracting(exception -> ((BusinessException) exception).getErrorType())
                .isEqualTo(AuthoringErrorType.AUTHORING_OUTLINE_NOT_READY);
    }

    @Test
    @DisplayName("이미 발행된 뼈대는 409다")
    void rejectsDoublePublish() {
        AuthoringOutline outline = prepareOutline(3, QuizPreset.BASIC_5, Set.of(), -1);
        publishService.publish(7L, outline.getId());

        assertThatThrownBy(() -> publishService.publish(7L, outline.getId()))
                .isInstanceOf(BusinessException.class)
                .extracting(exception -> ((BusinessException) exception).getErrorType())
                .isEqualTo(AuthoringErrorType.AUTHORING_OUTLINE_PUBLISHED);
        assertThat(courseRepository.count()).isEqualTo(1);
    }

    @Test
    @DisplayName("중간 스텝의 payload 검증이 실패하면 전체가 롤백된다")
    void rollsBackOnValidationFailure() {
        AuthoringOutline outline = prepareOutline(3, QuizPreset.BASIC_5, Set.of(), 2);

        assertThatThrownBy(() -> publishService.publish(7L, outline.getId()))
                .isInstanceOf(BusinessException.class)
                .extracting(exception -> ((BusinessException) exception).getErrorType())
                .isEqualTo(AuthoringErrorType.AUTHORING_OUTLINE_NOT_READY);
        assertThat(courseRepository.count()).isZero();
        assertThat(quizStepRepository.count()).isZero();
        assertThat(quizRepository.count()).isZero();
        assertThat(outlineRepository.findById(outline.getId()).orElseThrow().isPublished())
                .isFalse();
    }

    @Test
    @DisplayName("프리셋별 예상 소요 시간이 quiz_step에 반영된다")
    void carriesEstimatedMinutesFromPreset() {
        AuthoringOutline outline = prepareOutline(3, QuizPreset.LIGHT_3, Set.of(), -1);

        publishService.publish(7L, outline.getId());

        assertThat(quizStepRepository.findAll())
                .allSatisfy(step -> assertThat(step.getEstimatedMinutes()).isEqualTo(2));
        assertThat(quizRepository.count()).isEqualTo(9);
    }

    private AuthoringOutline prepareOutline(
            int stepCount, QuizPreset preset, Set<Integer> unapprovedSteps, int invalidStepIndex) {
        AuthoringOutline outline = outlineRepository.saveAndFlush(AuthoringOutline.create("테스트 코스", "CS", "목차", 7L));
        for (int index = 1; index <= stepCount; index++) {
            AuthoringOutlineStep step = stepRepository.saveAndFlush(
                    AuthoringOutlineStep.create(outline.getId(), index, "스텝 " + index, "학습 목표"));
            String payload = index == invalidStepIndex ? "{\"quizzes\":[]}" : payloadFor(preset);
            QuizDraft draft =
                    draftRepository.saveAndFlush(QuizDraft.createForOutlineStep("스텝 " + index, payload, preset, 7L));
            if (!unapprovedSteps.contains(index)) {
                draft.approve(7L, Instant.parse("2026-08-02T00:00:00Z"));
                draftRepository.saveAndFlush(draft);
            }
            step.attachDraft(draft.getId());
            stepRepository.saveAndFlush(step);
        }
        return outline;
    }

    private String payloadFor(QuizPreset preset) {
        return preset == QuizPreset.LIGHT_3
                ? GeneratedQuizJsonFixture.light3SetJson()
                : GeneratedQuizJsonFixture.validSetJson();
    }
}
