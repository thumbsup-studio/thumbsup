package studio.thumbsup.server.mascot.dto;

/** 보리 조회/먹이주기 공통 응답 — 이름은 아직 고정값이다(#35 단순판, 캐릭터 개인화는 범위 밖). */
public record MascotResponse(String name, int fullness) {

    private static final String NAME = "보리";

    public static MascotResponse from(int fullness) {
        return new MascotResponse(NAME, fullness);
    }
}
