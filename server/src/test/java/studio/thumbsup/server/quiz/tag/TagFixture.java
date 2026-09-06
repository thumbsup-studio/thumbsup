package studio.thumbsup.server.quiz.tag;

import java.time.Instant;
import org.springframework.test.util.ReflectionTestUtils;

/** 태그(#233, #324) 테스트 픽스처 — feature 소유. 영속화 전 id·감사 필드를 채워 단위테스트에서 사용한다. */
public final class TagFixture {

    public static final Instant CREATED_AT = Instant.parse("2026-07-08T00:00:00Z");

    public static Tag tag(Long id, String name, String category) {
        Tag tag = new Tag();
        ReflectionTestUtils.setField(tag, "id", id);
        ReflectionTestUtils.setField(tag, "name", name);
        ReflectionTestUtils.setField(tag, "category", category);
        ReflectionTestUtils.setField(tag, "createdAt", CREATED_AT);
        ReflectionTestUtils.setField(tag, "updatedAt", CREATED_AT);
        return tag;
    }

    public static TagDescription tagDescription(Long tagId, String content, Long quizStepId) {
        TagDescription description = new TagDescription();
        ReflectionTestUtils.setField(description, "tagId", tagId);
        ReflectionTestUtils.setField(description, "content", content);
        ReflectionTestUtils.setField(description, "quizStepId", quizStepId);
        return description;
    }

    public static UserTag userTag(Long userId, Long tagId, Instant learnedAt) {
        UserTag userTag = UserTag.create(userId, tagId);
        ReflectionTestUtils.setField(userTag, "createdAt", learnedAt);
        ReflectionTestUtils.setField(userTag, "updatedAt", learnedAt);
        return userTag;
    }

    public static UserTagStep userTagStep(Long userId, Long tagId, Long quizStepId) {
        return UserTagStep.create(userId, tagId, quizStepId);
    }

    public static QuizTag quizTag(Long quizId, Long tagId) {
        QuizTag quizTag = new QuizTag();
        ReflectionTestUtils.setField(quizTag, "quizId", quizId);
        ReflectionTestUtils.setField(quizTag, "tagId", tagId);
        return quizTag;
    }

    public static TagRelation relation(Long sourceTagId, Long targetTagId) {
        TagRelation relation = new TagRelation();
        ReflectionTestUtils.setField(relation, "sourceTagId", sourceTagId);
        ReflectionTestUtils.setField(relation, "targetTagId", targetTagId);
        return relation;
    }

    private TagFixture() {}
}
