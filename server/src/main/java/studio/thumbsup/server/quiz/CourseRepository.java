package studio.thumbsup.server.quiz;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CourseRepository extends JpaRepository<Course, Long> {

    /** MVP는 코스가 1개뿐이라 가장 먼저 생성된 코스를 "기본 코스"로 취급한다. */
    Optional<Course> findFirstByOrderByIdAsc();
}
