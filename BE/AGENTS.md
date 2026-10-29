# VINTIB BE Codex 작업 규칙

BE 규칙의 원문은 `CLAUDE.md`(이 폴더)다. Codex도 그 문서를 그대로 따른다 — 완료 기준, 테스트, 트랜잭션·스레드, 경매·포인트 불변식, 스키마, 코드 컨벤션.
루트 `AGENTS.md`·`CLAUDE.md`의 공통 규칙(범위, 파트 간 요청 문서, push 금지 등)이 먼저 적용된다.

- 검증 절차: 루트 `.claude/skills/verify/SKILL.md`(Gradle 전체 빌드 + 테스트, 테스트 수 유지)
- 새 패키지·파일 뼈대: `.claude/skills/scaffold/SKILL.md`, 엔드포인트 문서화: `.claude/skills/swagger/SKILL.md`(이 폴더 기준)
- FE·AI 코드는 직접 수정하지 않는다. 필요하면 루트 `docs/requests/`에 요청 문서를 남긴다(형식: 루트 `docs/requests/README.md`).
