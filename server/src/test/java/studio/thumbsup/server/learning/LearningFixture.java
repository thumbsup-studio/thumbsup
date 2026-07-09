package studio.thumbsup.server.learning;

import java.time.Instant;
import org.springframework.test.util.ReflectionTestUtils;

/** learning 테스트 픽스처 — feature 소유. 영속화 전 완전한 aggregate를 만들어 반환한다. */
public final class LearningFixture {

    public static final Instant CREATED_AT = Instant.parse("2026-07-07T00:00:00Z");

    /** id=1, "CS 기초" 코스에 화 3개(1~3화)를 채워 반환한다. */
    public static Course courseWithUnits(Long courseId) {
        Course course = Course.create("CS 기초", "CS");
        ReflectionTestUtils.setField(course, "id", courseId);
        setAuditFields(course);
        course.addUnit(1, "배열과 리스트", 3);
        course.addUnit(2, "스택과 큐", 3);
        course.addUnit(3, "해시 테이블", 3);
        int unitId = 1;
        for (Unit unit : course.getUnits()) {
            ReflectionTestUtils.setField(unit, "id", (long) unitId++);
            setAuditFields(unit);
        }
        return course;
    }

    public static UserProgress userProgress(Long id, Long userId, Long courseId, int cursor, int streak, int points) {
        UserProgress progress = UserProgress.create(userId, courseId, cursor, streak, points);
        ReflectionTestUtils.setField(progress, "id", id);
        setAuditFields(progress);
        return progress;
    }

    private static void setAuditFields(Object entity) {
        ReflectionTestUtils.setField(entity, "createdAt", CREATED_AT);
        ReflectionTestUtils.setField(entity, "updatedAt", CREATED_AT);
    }

    private LearningFixture() {}
}
