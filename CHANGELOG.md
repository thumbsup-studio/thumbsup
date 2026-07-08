# Changelog

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
