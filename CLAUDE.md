# VINTIB

SSAFY 6인 팀 프로젝트 **VINTIB**(실시간 라이브·경매와 AI 가상 시착을 결합한 빈티지 의류 거래 플랫폼, 2026-07-15 ~ 08-24)의 모노레포다. 이 문서는 모든 파트에 공통인 에이전트 규칙이다.

## 모노레포 구조와 파트별 규칙

| 폴더 | 파트 | 에이전트 규칙 |
| --- | --- | --- |
| `BE/` | 백엔드(Spring Boot) | `BE/CLAUDE.md` · Codex용 `BE/AGENTS.md` · 스킬 `scaffold`·`swagger` |
| `FE/` | 프론트엔드(Vue) | `FE/CLAUDE.md` · Codex용 `FE/AGENTS.md`(FE 컨벤션 원문) |
| `AI/` | AI 게이트웨이(FastAPI)와 GPU 추론 워커(`AI/worker/`, 팀원 노트북에서 실행) | `AI/CLAUDE.md`(AI 컨벤션 원문) · Codex용 `AI/AGENTS.md` |
| `infra/`, `docker-compose*.yml` | 인프라(BE·인프라 담당) | 이 문서 · 서버 문서 `infra/docs/` |
| `docs/` | 공유 문서 | `docs/README.md` |

- 이 문서가 모든 파트에 공통이고, 파트 문서는 그 파트 폴더에서만 더한다. 둘이 다르면 이 문서가 먼저다.
- **세션은 두 가지다.** 레포 루트에서 연 세션은 BE·인프라·문서를 다루고, FE·AI 기능 코드를 고치려 하면 훅이 확인을 요청한다. 파트 폴더(`FE/`·`AI/`·`BE/`)에서 연 세션은 그 파트만 고치고, 다른 파트 수정은 그 파트의 `.claude/settings.json` 훅이 막는다.
- **어느 세션이든 같은 가드가 걸린다**(`.claude/hooks/guard-command.sh`): git push, 커밋의 에이전트 표기, 볼륨 삭제, 운영 `.env` 출력, 같은 호스트의 다른 팀 러너 조작.
- Codex는 루트와 파트별 `AGENTS.md`를 읽는다. 루트 `.codex/hooks.json`이 루트 세션의 FE·AI 기능 코드 수정을 막는다.
- 공용 절차는 스킬로 둔다: `/verify`(BE 빌드·테스트), `/request`(파트 간 요청·응답).

## 공유 문서와 요청

- **문서 지도는 [`docs/README.md`](docs/README.md).** 기준 자료 색인은 `docs/references/README.md`, 파트 간 요청·응답은 `docs/requests/`.
- **레포 문서가 노션보다 우선한다.** 노션이 레포 사본보다 새로워 보이면 사용자에게 알리고, 사본 갱신은 묻고 나서 한다.
- **세션을 시작하면** `docs/requests/README.md`에서 상태가 `요청`이고 받는 쪽이 지금 작업하는 파트 또는 `owner`인 문서가 있는지 보고, 있으면 먼저 알린다.
- 처리한 요청 문서는 지우지 않고 상태만 바꾼다.
- 레포를 받은 뒤 `bash setup.sh`를 한 번 실행하면 pull 직후 바뀐 요청 문서가 터미널에 나온다.

## 파트 사이 규칙

- **다른 파트 코드는 직접 고치지 않는다.** 다른 파트의 변경이나 결정이 필요하면 `/request`로 요청 문서를 남긴다. 루트 세션에서 `FE/src`·`AI/app`·`AI/worker`를 고치려 하면 훅이 확인을 요청한다 — 그 파트가 요청한 변경이 아니면 멈춘다.
- **API 계약을 지킨다.** REST 경로·요청/응답 필드·STOMP destination·에러 코드·시각 표현은 다른 파트가 그대로 쓴다. 바꿔야 하면 쓰는 파트와 요청 문서로 먼저 합의한다. `ErrorCode`의 기존 값은 바꾸지 않는다(FE가 분기한다).
- **새 기능은 계획부터.** 신규 API·화면·도메인 로직은 `docs/plans/<파트>/`에 계획을 남기고 승인 후 구현한다(`docs/plans/README.md`). 기능 정의서(`docs/references/feature-spec.md`)의 범위를 벗어난 기능을 임의로 만들지 않는다. 버그 수정처럼 설계 판단이 필요 없는 변경에는 적용하지 않는다.

## 서버 운영

서버 구성과 배포 흐름은 `infra/docs/`.

- **볼륨을 지우지 않는다**(`postgres-data`, `minio-data`, `redis-data`, `caddy-data` 등). DB·MinIO 자격증명이 볼륨을 처음 만들 때의 값으로 굳어 있어, 지우면 데이터와 함께 접속도 깨진다. `down -v`, `volume rm`, `system prune --volumes`는 훅이 막는다.
- **`.env` 내용을 출력하지 않는다.** 확인은 키 이름만(`cut -d= -f1 .env`). `infra/ec2/init-env.sh`는 이미 `.env`가 있으면 멈추며, 재생성하지 않는다.
- 운영 compose는 `-f docker-compose.yml -f docker-compose.prod.yml -p vintib`로 파일을 명시한다. 로컬용 `docker-compose.override.yml`이 섞이면 DB·Redis가 호스트에 노출된다.
- 베이스 `docker-compose.yml`에는 호스트 포트를 넣지 않는다(로컬용은 override에만). 외부에 열 포트는 prod 파일에서 `0.0.0.0:`을 명시한다 — 도커 데몬이 `127.0.0.1`에만 바인딩하도록 설정된 서버가 있다.
- 컨테이너 기동·중단, UFW·sysctl·systemd 변경 등 서버 상태를 바꾸는 명령은 근거를 먼저 확인하고 실행한다. 라이브 진행 중이면 하지 않는다.

## Git

- **push는 사용자가 직접 한다.** 에이전트는 커밋까지만 하고, 필요한 push 명령을 알려 준다(설정과 훅이 막는다).
- **커밋에 에이전트 표기(Co-Authored-By 등)를 넣지 않는다**(훅이 막는다). 모든 커밋은 사용자 이름으로 남는다.
- 이미 push된 커밋은 다시 쓰지 않는다(amend·rebase·force 금지).
- 커밋 메시지·브랜치 규칙은 `docs/commit-convention.md`(팀 프로젝트 기간 규칙).
- Windows에서 내보내기·압축은 `git -c core.autocrlf=false archive`로 한다. 기본값이면 Dockerfile·yml이 CRLF로 나가 리눅스에서 깨진다.

## 깨면 안 되는 설계 (바꾸려면 먼저 사용자와 합의)

- **시각 = 오프셋 없는 KST `LocalDateTime`.** 컨테이너 타임존을 `Asia/Seoul`로 고정한다(compose `TZ` + Dockerfile `-Duser.timezone`). UTC로 돌면 모든 시각이 9시간 어긋난다.
- **입찰 동시성 = DB 비관적 락 + 부분 UNIQUE 인덱스.** Redis 분산락·MQ는 검토 후 기각했다(`docs/plans/BE/JY008-live-screen-complete.md` 설계 판단 1).
- **바깥에 알리는 일은 커밋 후에 한다.** STOMP 브로드캐스트, 외부 리소스 정리(LiveKit room 등).

## 참고 문서

| 알고 싶은 것 | 문서 |
| --- | --- |
| 문서가 어디 있는지, 무엇이 기준인지 | `docs/README.md` |
| 기능 범위·요구사항·유스케이스 | `docs/references/` |
| 팀 시절 설계 판단 | `docs/plans/BE/JY0xx-*.md` (JY006 MinIO, JY008 경매, JY012 포트 80) |
| 서버·배포(이전 서버 기준, 일부 낡음) | `infra/docs/ec2.md`, `infra/docs/cicd.md` |
| DB 스키마 문서(운영 DB와 다르다) | `BE/docs/db/` |
| API 전수 | `docs/APIs.md` |
