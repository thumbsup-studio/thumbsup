package studio.thumbsup.server.common.response;

/**
 * Service → Controller로 "데이터 + 커서 meta"를 함께 나르는 조립 헬퍼.
 *
 * <p>컨트롤러는 엔티티를 만질 수 없으므로(ArchUnit 강제) DTO 변환은 Service에서 끝내고,
 * 컨트롤러는 {@code ApiResponse.success(page.data(), page.meta())}로 감싸기만 한다.
 */
public record CursorPage<T>(T data, CursorMeta meta) {}
