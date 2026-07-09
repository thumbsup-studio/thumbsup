package studio.thumbsup.server.common;

import jakarta.annotation.PostConstruct;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.Table;
import java.util.List;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Repository 통합 테스트 전용 — 모든 테이블을 TRUNCATE하고 AUTO_INCREMENT를 리셋한다.
 * Flyway 시드 데이터(예: quiz 샘플, learning "CS 기초" 시드)와 테스트가 삽입하는 값이 겹쳐
 * unique 제약 위반이나 "첫 번째/특정 id" 가정이 깨지는 것을 막는다 — 각 테스트를 빈 테이블에서 시작시킨다.
 *
 * <p>테이블명은 엔티티의 {@code @Table(name=...)} 값을 그대로 읽는다 — 이 프로젝트의 모든 엔티티는
 * 테이블명을 명시하므로(예: {@code User} → {@code users}, MySQL 예약어 회피) 클래스명을 스네이크케이스로
 * 변환하는 방식은 이런 불일치를 놓친다.
 *
 * <p>⚠️ {@code TRUNCATE}는 MySQL에서 암묵적 커밋을 일으켜 Spring 테스트 트랜잭션 롤백으로 되돌릴 수
 * 없다 — {@code @BeforeEach}에서 매번 명시적으로 호출해 비우는 용도로만 쓴다.
 */
@Component
public class DatabaseCleanUp {

    @PersistenceContext
    private EntityManager entityManager;

    private List<String> tableNames;

    @PostConstruct
    public void init() {
        tableNames = entityManager.getMetamodel().getEntities().stream()
                .map(entityType -> entityType.getJavaType().getAnnotation(Entity.class) != null
                        ? entityType.getJavaType().getAnnotation(Table.class)
                        : null)
                .filter(table -> table != null && !table.name().isBlank())
                .map(Table::name)
                .distinct()
                .toList();
    }

    @Transactional
    public void execute() {
        entityManager.flush();
        entityManager.createNativeQuery("SET FOREIGN_KEY_CHECKS = 0").executeUpdate();

        for (String tableName : tableNames) {
            entityManager
                    .createNativeQuery("TRUNCATE TABLE `" + tableName + "`")
                    .executeUpdate();
            entityManager
                    .createNativeQuery("ALTER TABLE `" + tableName + "` AUTO_INCREMENT = 1")
                    .executeUpdate();
        }

        entityManager.createNativeQuery("SET FOREIGN_KEY_CHECKS = 1").executeUpdate();
    }
}
