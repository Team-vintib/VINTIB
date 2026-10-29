# AGENTS.md

Codex 등 Claude Code가 아닌 에이전트의 진입점이다. 규칙은 한 벌만 유지하므로 아래 문서를 그대로 따른다.

1. 루트 `CLAUDE.md` — 모든 파트에 공통: 목표, 모노레포 구조, 범위, 작업 방식, 운영 서버, Git 규칙
2. 작업하는 파트의 `AGENTS.md` — `BE/AGENTS.md`, `FE/AGENTS.md`, `AI/AGENTS.md`. 파트 규칙 원문(`BE/CLAUDE.md`, `FE/AGENTS.md`, `AI/CLAUDE.md`)을 가리킨다
3. `.claude/skills/*/SKILL.md` — 공용 절차(검증, 요청·응답)
4. `docs/README.md` — 공유 문서 지도. 기준 자료와 파트 간 요청의 위치, 우선순위

Claude Code의 훅(`.claude/hooks/`)은 Codex에서 돌지 않는다. Codex에는 루트 `.codex/hooks.json`이 FE·AI 기능 코드 수정만 막으므로, push 금지·볼륨 삭제 금지·`.env` 출력 금지 같은 나머지 가드는 스스로 지킨다.
