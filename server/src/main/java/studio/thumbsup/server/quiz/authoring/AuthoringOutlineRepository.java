package studio.thumbsup.server.quiz.authoring;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AuthoringOutlineRepository extends JpaRepository<AuthoringOutline, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT o FROM AuthoringOutline o WHERE o.id = :id")
    Optional<AuthoringOutline> findByIdForUpdate(@Param("id") Long id);

    List<AuthoringOutline> findAllByOrderByIdDesc();
}
