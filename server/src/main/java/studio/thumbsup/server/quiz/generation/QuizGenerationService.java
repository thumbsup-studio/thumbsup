package studio.thumbsup.server.quiz.generation;

import org.springframework.stereotype.Service;

/**
 * 엘리스 모델로 문제 세트를 생성해 DB에 저장한다(#26). 스텝당 5문제(하2·중2·상1) 고정 구성이며,
 * 변형 출제(#18)는 지원하지 않는다 — 슬롯당 문제 1개로 고정된 현재 스키마의 전제와 일치시킨다.
 *
 * <p>파싱·검증은 {@link GeneratedQuizValidator}에 위임한다 — 저작 파이프라인(#174)의 REVIEW/IMPROVE 잡도
 * 같은 검증 규칙을 재사용해야 해서 이 서비스 밖으로 분리했다.
 */
@Service
public class QuizGenerationService {

    private final EliceClient eliceClient;
    private final QuizPersister quizPersister;
    private final GeneratedQuizValidator validator;

    public QuizGenerationService(
            EliceClient eliceClient, QuizPersister quizPersister, GeneratedQuizValidator validator) {
        this.eliceClient = eliceClient;
        this.quizPersister = quizPersister;
        this.validator = validator;
    }

    /** {@link #generateStep(Long, String, GenerationLevel)}를 콘텐츠 난이도 힌트 없이(STANDARD) 호출한다. */
    public int generateStep(Long courseId, String courseTopic) {
        return generateStep(courseId, courseTopic, GenerationLevel.STANDARD);
    }

    /**
     * 코스 주제로 한 스텝(5문제)을 생성·저장하고, 배정된 스텝 번호를 반환한다. {@code courseId}가 속할 코스를
     * 정한다 — stepOrder는 코스와 무관하게 전역 순번이라, 어느 코스 소속인지는 이 값으로만 알 수 있다.
     * {@code level}은 슬롯 구성(하2·중2·상1)이 정하는 문제 형식과 별개로 콘텐츠 깊이를 조절한다.
     * LLM 호출(수십 초 소요 가능)은 여기서 트랜잭션 밖에 두고, DB 저장만 {@link QuizPersister}의
     * 트랜잭션으로 묶는다 — 그렇지 않으면 외부 호출 대기 시간만큼 DB 커넥션을 점유하게 된다.
     */
    public int generateStep(Long courseId, String courseTopic, GenerationLevel level) {
        String rawResponse = eliceClient.generate(QuizGenerationPromptBuilder.build(courseTopic, level));
        GeneratedQuizSet generated = validator.parse(rawResponse);
        validator.validateSet(generated);
        return quizPersister.persist(courseId, courseTopic, generated);
    }
}
