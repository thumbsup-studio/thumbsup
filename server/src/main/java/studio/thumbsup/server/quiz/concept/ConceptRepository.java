package studio.thumbsup.server.quiz.concept;

import org.springframework.data.jpa.repository.JpaRepository;

/** 그래프 노드 상세(label/category) 조립은 상속받은 {@code findAllById}로 충분하다. */
public interface ConceptRepository extends JpaRepository<Concept, Long> {}
