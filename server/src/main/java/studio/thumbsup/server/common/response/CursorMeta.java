package studio.thumbsup.server.common.response;

/**
 * 커서 페이지네이션 meta — 계약: docs/api-standard.md §7.
 *
 * <p>nextCursor는 불투명(opaque) 문자열이다. 클라이언트는 해석하지 않고 그대로 다음 요청에 전달한다.
 * 마지막 페이지면 {@code hasNext=false, nextCursor=null}.
 */
public record CursorMeta(boolean hasNext, String nextCursor) {

    public static CursorMeta of(boolean hasNext, String nextCursor) {
        return new CursorMeta(hasNext, hasNext ? nextCursor : null);
    }

    public static CursorMeta last() {
        return new CursorMeta(false, null);
    }
}
