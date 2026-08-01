package studio.thumbsup.server.quiz.course;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CourseRepository extends JpaRepository<Course, Long> {

    /** MVP는 코스가 1개뿐이라 가장 먼저 생성된 코스를 "기본 코스"로 취급한다. */
    Optional<Course> findFirstByOrderByIdAsc();

    /** 코스 목록 조회(#247) — 정렬 순서를 명시해 응답 순서를 결정적으로 만든다. */
    List<Course> findAllByOrderByIdAsc();
}
