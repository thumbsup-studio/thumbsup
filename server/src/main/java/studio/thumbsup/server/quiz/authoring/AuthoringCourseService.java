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
        return new AuthoringCourseListResponse(courseRepository.findAll().stream()
                .map(AuthoringCourseResponse::from)
                .toList());
    }
}
