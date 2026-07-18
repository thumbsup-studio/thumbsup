package studio.thumbsup.server.quiz.authoring.dto;

import studio.thumbsup.server.quiz.Course;

public record AuthoringCourseResponse(Long courseId, String title, String category) {

    public static AuthoringCourseResponse from(Course course) {
        return new AuthoringCourseResponse(course.getId(), course.getTitle(), course.getCategory());
    }
}
