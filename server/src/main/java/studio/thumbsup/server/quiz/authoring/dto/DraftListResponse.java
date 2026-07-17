package studio.thumbsup.server.quiz.authoring.dto;

import java.util.List;

/** 리스트 키는 {@code drafts} — 앱·브리지와 공유하는 계약(docs/superpowers/plans/2026-07-14-quiz-authoring-server.md). */
public record DraftListResponse(List<DraftSummaryResponse> drafts) {}
