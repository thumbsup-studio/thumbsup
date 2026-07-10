package studio.thumbsup.server.auth.dto;

import studio.thumbsup.server.auth.User;

/** GET /api/v1/auth/me 전용 응답 DTO — 다른 API와 공유하지 않는다. */
public record MeResponse(String email) {

    public static MeResponse from(User user) {
        return new MeResponse(user.getEmail());
    }
}
