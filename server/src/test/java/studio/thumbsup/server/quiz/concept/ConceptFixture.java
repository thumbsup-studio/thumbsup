package studio.thumbsup.server.quiz.concept;

import java.time.Instant;
import org.springframework.test.util.ReflectionTestUtils;

/** 개념(#233) 테스트 픽스처 — feature 소유. 영속화 전 id·감사 필드를 채워 단위테스트에서 사용한다. */
public final class ConceptFixture {

    public static final Instant CREATED_AT = Instant.parse("2026-07-08T00:00:00Z");

    public static Concept concept(Long id, String name, String category) {
        Concept concept = new Concept();
        ReflectionTestUtils.setField(concept, "id", id);
        ReflectionTestUtils.setField(concept, "name", name);
        ReflectionTestUtils.setField(concept, "category", category);
        ReflectionTestUtils.setField(concept, "createdAt", CREATED_AT);
        ReflectionTestUtils.setField(concept, "updatedAt", CREATED_AT);
        return concept;
    }

    public static ConceptDescription conceptDescription(Long conceptId, String content, Long quizStepId) {
        ConceptDescription description = new ConceptDescription();
        ReflectionTestUtils.setField(description, "conceptId", conceptId);
        ReflectionTestUtils.setField(description, "content", content);
        ReflectionTestUtils.setField(description, "quizStepId", quizStepId);
        return description;
    }

    public static UserConcept userConcept(Long userId, Long conceptId, Instant learnedAt) {
        UserConcept userConcept = UserConcept.create(userId, conceptId);
        ReflectionTestUtils.setField(userConcept, "createdAt", learnedAt);
        ReflectionTestUtils.setField(userConcept, "updatedAt", learnedAt);
        return userConcept;
    }

    public static UserConceptStep userConceptStep(Long userId, Long conceptId, Long quizStepId) {
        return UserConceptStep.create(userId, conceptId, quizStepId);
    }

    public static QuizConcept quizConcept(Long quizId, Long conceptId) {
        QuizConcept quizConcept = new QuizConcept();
        ReflectionTestUtils.setField(quizConcept, "quizId", quizId);
        ReflectionTestUtils.setField(quizConcept, "conceptId", conceptId);
        return quizConcept;
    }

    public static ConceptRelation relation(Long sourceConceptId, Long targetConceptId) {
        ConceptRelation relation = new ConceptRelation();
        ReflectionTestUtils.setField(relation, "sourceConceptId", sourceConceptId);
        ReflectionTestUtils.setField(relation, "targetConceptId", targetConceptId);
        return relation;
    }

    private ConceptFixture() {}
}
