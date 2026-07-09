# Changelog

## [0.4.0](https://github.com/thumbsup-studio/thumbsup/compare/v0.3.0...v0.4.0) (2026-07-09)


### Features

* **app:** add insight handoff flow ([7254a41](https://github.com/thumbsup-studio/thumbsup/commit/7254a41a7a88f80c67c0eeaf53b64c7c407d72fe))
* **app:** implement play quiz session ([17caa18](https://github.com/thumbsup-studio/thumbsup/commit/17caa1811c6b2f6dbe87e9f4c2e1fcce43aed8ef))
* **app:** Play 문제 풀이와 Insight 해설 흐름 구현 ([4474717](https://github.com/thumbsup-studio/thumbsup/commit/44747171edb2ea6a9d96a97749fbf7244af73369))
* **app:** 로그인·회원가입 화면과 auth API 연동 ([#1](https://github.com/thumbsup-studio/thumbsup/issues/1)) ([#100](https://github.com/thumbsup-studio/thumbsup/issues/100)) ([b6056e7](https://github.com/thumbsup-studio/thumbsup/commit/b6056e7290f63fb202171252bb8f43f5a2566f26))
* **app:** 지식 그래프(Atlas /history) 화면과 그래프 프리미티브 ([#10](https://github.com/thumbsup-studio/thumbsup/issues/10)) ([#101](https://github.com/thumbsup-studio/thumbsup/issues/101)) ([3b731cc](https://github.com/thumbsup-studio/thumbsup/commit/3b731cc7cf273a865d1e96621a68d370a1750fad))
* **server:** 다음 문제 조회 API — 유저별 커리큘럼 진행 ([#41](https://github.com/thumbsup-studio/thumbsup/issues/41)) ([c2f6110](https://github.com/thumbsup-studio/thumbsup/commit/c2f6110c0aaf41acf41c7ea96ec07737977eb6b3))
* **server:** 정답 확인 API + 다음 문제 선형 진행 수정 ([#41](https://github.com/thumbsup-studio/thumbsup/issues/41), [#42](https://github.com/thumbsup-studio/thumbsup/issues/42)) ([55f67c1](https://github.com/thumbsup-studio/thumbsup/commit/55f67c1ca5167dcb71ccf74dae17fc31f0e61c35))
* **server:** 정답 확인 API 엔드포인트·DTO ([#42](https://github.com/thumbsup-studio/thumbsup/issues/42)) ([cedff65](https://github.com/thumbsup-studio/thumbsup/commit/cedff65274e09b7e693ab98e21956ea2f8a54726))
* **server:** 퀴즈 복습(재시도) 허용 — 오답 이력 보존 ([#41](https://github.com/thumbsup-studio/thumbsup/issues/41)) ([2e1f147](https://github.com/thumbsup-studio/thumbsup/commit/2e1f147dd6eaf4a659feb2154386b469a74d1b64))


### Bug Fixes

* **app:** align play flow styles with design tokens ([1837df7](https://github.com/thumbsup-studio/thumbsup/commit/1837df7783c21a27adfbb22165812ec690a6e39f))
* **app:** merge conflict ([8e4c273](https://github.com/thumbsup-studio/thumbsup/commit/8e4c2736f3861db3eb28f958c0e38836bbd99c60))
* **app:** sanitize visual qa screenshot filenames ([b004a2f](https://github.com/thumbsup-studio/thumbsup/commit/b004a2f621775401fbb04177c706970ba358b0de))
* **app:** use session total in play progress labels ([8732124](https://github.com/thumbsup-studio/thumbsup/commit/87321247074864bf76d6ccd1c151b1ea16a4540b))
* **server:** CodeRabbit 지적 반영 — 테스트 구조·상수 추출 ([#41](https://github.com/thumbsup-studio/thumbsup/issues/41)) ([2990dbe](https://github.com/thumbsup-studio/thumbsup/commit/2990dbe83ae0edf6dc2b3be69bc896748da17f9e))
* **server:** 다음 문제 선형 진행 + 정답 확인 서비스 로직 ([#41](https://github.com/thumbsup-studio/thumbsup/issues/41), [#42](https://github.com/thumbsup-studio/thumbsup/issues/42)) ([d2d88f4](https://github.com/thumbsup-studio/thumbsup/commit/d2d88f422d8d6053cd667e5bcf22e364c69e19a8))
* **server:** 정답 제출 API 동시성·접근 검증·조회 효율 개선 ([#42](https://github.com/thumbsup-studio/thumbsup/issues/42)) ([478fdde](https://github.com/thumbsup-studio/thumbsup/commit/478fddef2457feeec2badf7985557ef3304a662a))

## [0.3.0](https://github.com/thumbsup-studio/thumbsup/compare/v0.2.0...v0.3.0) (2026-07-08)


### Features

* **app:** 디자인 시스템·3단 하네스 파운데이션 ([#38](https://github.com/thumbsup-studio/thumbsup/issues/38)) ([01b2da8](https://github.com/thumbsup-studio/thumbsup/commit/01b2da8711730aca1090a98233592c32b4850f5b))
* **server:** refresh_token.user_id 유니크 제약 추가 ([#96](https://github.com/thumbsup-studio/thumbsup/issues/96)) ([269a8a0](https://github.com/thumbsup-studio/thumbsup/commit/269a8a09b39f8d8e7e396f723adbff151b9bf928))
* **server:** 로그인/회원가입/토큰 재발급 API 구현 ([#44](https://github.com/thumbsup-studio/thumbsup/issues/44)) ([5486844](https://github.com/thumbsup-studio/thumbsup/commit/5486844f3de5ef8d86ca0e90fabe422807f5da5f))
* **server:** 로그인/회원가입/토큰 재발급 API 구현 ([#44](https://github.com/thumbsup-studio/thumbsup/issues/44)) ([b0f6a72](https://github.com/thumbsup-studio/thumbsup/commit/b0f6a725c42e4a79d2681cfab5737ceb17d76bee))
* **server:** 리프레시 토큰 지원을 위한 JWT 인프라 확장 ([#44](https://github.com/thumbsup-studio/thumbsup/issues/44)) ([ac21630](https://github.com/thumbsup-studio/thumbsup/commit/ac21630854d02deb643e8bbe10470d1eb5430b28))
* **server:** 인증 도메인 엔티티·리포지토리·마이그레이션 추가 ([#44](https://github.com/thumbsup-studio/thumbsup/issues/44)) ([1295ed5](https://github.com/thumbsup-studio/thumbsup/commit/1295ed5734568b3091779bc31ae49aedec6fa6b3))
* **server:** 퀴즈 문제 세트 DB 스키마·저장 로직 ([#40](https://github.com/thumbsup-studio/thumbsup/issues/40)) ([991d89a](https://github.com/thumbsup-studio/thumbsup/commit/991d89a193b7c3d765e8c22eab02420ca0cea2c9))


### Bug Fixes

* **server:** auth 마이그레이션 버전 재조정 ([#96](https://github.com/thumbsup-studio/thumbsup/issues/96)) ([5ef37df](https://github.com/thumbsup-studio/thumbsup/commit/5ef37df6bade0b47ec923cf885923cdd0bf13ad4))
* **server:** Flyway 마이그레이션 버전 충돌 수정 및 refresh_token 유니크 제약 ([#96](https://github.com/thumbsup-studio/thumbsup/issues/96)) ([3eba789](https://github.com/thumbsup-studio/thumbsup/commit/3eba789b122bbd8d2e0e86060afce87a2ec32054))
* **server:** refresh token 발급을 delete+insert 대신 원자적 upsert로 변경 ([#96](https://github.com/thumbsup-studio/thumbsup/issues/96)) ([ccf28c7](https://github.com/thumbsup-studio/thumbsup/commit/ccf28c71a83c5f6d880ddf141cfc0739fad0ea5c))

## [0.2.0](https://github.com/thumbsup-studio/thumbsup/compare/v0.1.0...v0.2.0) (2026-07-08)


### Features

* **app:** home 레이아웃 변경 ([#2](https://github.com/thumbsup-studio/thumbsup/issues/2)) ([f5395a4](https://github.com/thumbsup-studio/thumbsup/commit/f5395a45f8a13a7bb4f09981d80201fda70c9468))
* **app:** 하단 탭 PNG 아이콘 적용 ([#2](https://github.com/thumbsup-studio/thumbsup/issues/2)) ([36265bd](https://github.com/thumbsup-studio/thumbsup/commit/36265bd663d8a79834d04ac298b2b8e36590a46d))
* **app:** 홈 투데이 MVP 구현 ([#2](https://github.com/thumbsup-studio/thumbsup/issues/2)) ([d1bfd47](https://github.com/thumbsup-studio/thumbsup/commit/d1bfd47a62d60b9518cdbea3576a369f576a1c30))
* **app:** 홈 투데이 MVP 구현 ([#2](https://github.com/thumbsup-studio/thumbsup/issues/2)) ([43fcff2](https://github.com/thumbsup-studio/thumbsup/commit/43fcff2689f925e7cf79c640ba9f19b49df0badd))
* **app:** 홈 헤더와 전역 토스트 개선 ([#2](https://github.com/thumbsup-studio/thumbsup/issues/2)) ([2561c8a](https://github.com/thumbsup-studio/thumbsup/commit/2561c8a2abd7eac0dd4b37cc1bd4bef27b0243d6))


### Bug Fixes

* **app:** ci 포맷 에러 ([#2](https://github.com/thumbsup-studio/thumbsup/issues/2)) ([c9d2922](https://github.com/thumbsup-studio/thumbsup/commit/c9d2922ea2bd0418034231d0969e05d3477bfee4))
