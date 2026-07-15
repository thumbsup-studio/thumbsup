package studio.thumbsup.server.auth.dto;

import studio.thumbsup.server.auth.User;

/**
 * GET /api/v1/auth/me 전용 응답 DTO — 다른 API와 공유하지 않는다.
 *
 * <p>{@code role}은 "USER"|"ADMIN" — FE가 이 값으로 저작(#174) 진입을 게이팅한다(app #176 계약).
 */
public record MeResponse(String email, String role) {

    public static MeResponse from(User user) {
        return new MeResponse(user.getEmail(), user.getRole().name());
    }
}
