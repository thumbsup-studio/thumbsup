package studio.thumbsup.server.architecture;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.methods;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noFields;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;

import com.tngtech.archunit.base.DescribedPredicate;
import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.core.domain.JavaConstructorCall;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import jakarta.persistence.Entity;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.repository.Repository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.RestController;

/**
 * 아키텍처 규칙을 CI에서 강제한다 — 위반 시 빌드 실패.
 * 규칙의 근거: server/docs/, docs/error-spec.md. (빈 규칙 허용: src/test/resources/archunit.properties)
 */
@AnalyzeClasses(packages = "studio.thumbsup.server", importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

    // ⚠️ ArchUnit 한계: 메서드 레퍼런스(IllegalArgumentException::new)는 탐지 불가 — 코드리뷰/CodeRabbit이 커버

    @ArchTest
    static final ArchRule 필드_주입_금지 =
            noFields().should().beAnnotatedWith(Autowired.class).because("생성자 주입만 허용한다 — Spring 없이 new로 단위테스트 가능해야 한다");

    @ArchTest
    static final ArchRule 표준_예외_생성_금지 = noClasses()
            .should()
            .callConstructorWhere(
                    new DescribedPredicate<JavaConstructorCall>("JDK 표준 런타임 예외(java.*의 RuntimeException 계열) 생성") {
                        @Override
                        public boolean test(JavaConstructorCall call) {
                            JavaClass target = call.getTarget().getOwner();
                            boolean jdkRuntimeException = target.isAssignableTo(RuntimeException.class)
                                    && target.getPackageName().startsWith("java.");
                            if (!jdkRuntimeException) {
                                return false;
                            }
                            // 서브클래스 생성자의 super(...) 호출은 허용
                            // (예: BusinessException extends RuntimeException)
                            return !call.getOriginOwner().isAssignableTo(target.getFullName());
                        }
                    })
            .because("비즈니스 예외는 BusinessException(ErrorType)으로만 던진다 — docs/error-spec.md");

    @ArchTest
    static final ArchRule 트랜잭션_메서드는_서비스에만 = methods()
            .that()
            .areAnnotatedWith(Transactional.class)
            .should()
            .beDeclaredInClassesThat()
            .areAnnotatedWith(Service.class)
            .because("@Transactional 경계는 Service 계층에만 둔다");

    @ArchTest
    static final ArchRule 트랜잭션_클래스는_서비스에만 = classes()
            .that()
            .areAnnotatedWith(Transactional.class)
            .should()
            .beAnnotatedWith(Service.class)
            .because("@Transactional 경계는 Service 계층에만 둔다");

    @ArchTest
    static final ArchRule 컨트롤러는_리포지토리_직접_사용_금지 = noClasses()
            .that()
            .areAnnotatedWith(RestController.class)
            .should()
            .dependOnClassesThat()
            .areAssignableTo(Repository.class)
            .because("Controller → Service → Repository 레이어 방향을 지킨다");

    @ArchTest
    static final ArchRule 컨트롤러는_엔티티_사용_금지 = noClasses()
            .that()
            .areAnnotatedWith(RestController.class)
            .should()
            .dependOnClassesThat()
            .areAnnotatedWith(Entity.class)
            .because("엔티티를 API로 직접 노출하지 않는다 — 항상 API별 DTO(record)");

    @ArchTest
    static final ArchRule 피처_간_직접_의존_금지 = slices().matching("studio.thumbsup.server.(*)..")
            .namingSlices("$1")
            .should()
            .notDependOnEachOther()
            .ignoreDependency(
                    DescribedPredicate.alwaysTrue(),
                    JavaClass.Predicates.resideInAPackage("studio.thumbsup.server.common.."));
}
