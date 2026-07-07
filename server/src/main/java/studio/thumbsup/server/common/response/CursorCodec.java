package studio.thumbsup.server.common.response;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.CommonErrorType;

/**
 * 커서를 불투명(opaque) 문자열로 인코딩/디코딩한다 — 계약: docs/api-standard.md §7.
 *
 * <p>클라이언트에 내부 id를 평문 노출하지 않고, 나중에 정렬 키가 복합(예: createdAt+id)으로 바뀌어도
 * 인코딩 방식만 확장하면 되도록 경계를 만든다. 지금은 단일 id를 Base64로 감싼다.
 *
 * <p>깨진 커서는 클라이언트가 값을 조작한 것이므로 {@code INVALID_INPUT}으로 처리한다.
 */
public final class CursorCodec {

    public static String encodeId(long id) {
        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(Long.toString(id).getBytes(StandardCharsets.UTF_8));
    }

    public static long decodeId(String cursor) {
        try {
            byte[] decoded = Base64.getUrlDecoder().decode(cursor);
            return Long.parseLong(new String(decoded, StandardCharsets.UTF_8));
        } catch (IllegalArgumentException e) {
            throw new BusinessException(CommonErrorType.INVALID_INPUT, e);
        }
    }

    private CursorCodec() {}
}
