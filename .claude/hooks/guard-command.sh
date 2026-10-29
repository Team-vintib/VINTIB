#!/usr/bin/env bash
# PreToolUse 가드 — Bash·PowerShell 명령.
#
# 되돌리기 어렵거나 이 레포 규칙(루트 CLAUDE.md)이 금지한 명령을 막고(deny),
# 서버 상태를 크게 바꾸는 명령은 사람에게 확인을 받는다(ask).
#
# 입력: 훅 JSON(stdin). jq 없이 동작해야 해서(로컬 Git Bash에 없음) sed 로 "command" 값만 꺼낸다.
# 설명(description) 필드까지 검사하면 "push 규칙 안내" 같은 문장에도 걸리므로 명령 문자열만 본다.
input=$(cat)
cmd=$(printf '%s' "$input" | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n 1)
[ -z "$cmd" ] && exit 0

decide() { # $1=deny|ask  $2=사유
    reason=$(printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$reason"
    exit 0
}
has()  { printf '%s' "$cmd" | grep -Eq -- "$1"; }
hasi() { printf '%s' "$cmd" | grep -Eqi -- "$1"; }

# ---------- Git ----------
# git 바로 뒤(전역 옵션 -c/-C/--xxx 를 건너뛴 자리)의 하위 명령이 push 일 때만 막는다.
# 커밋 메시지에 "push"가 들어간 경우는 하위 명령이 commit 이라 걸리지 않는다.
GIT='(^|[^[:alnum:]_./-])git([[:space:]]+(-c|-C)[[:space:]]+[^[:space:]]+|[[:space:]]+--?[[:alnum:]-]+(=[^[:space:]]+)?)*[[:space:]]+'
has "${GIT}push([[:space:]]|\$|\\\\|\")" \
    && decide deny "push 는 사용자가 직접 한다(CLAUDE.md Git). 커밋까지만 하고 실행할 push 명령을 사용자에게 알려라."
has "${GIT}commit" && hasi 'co-authored-by' \
    && decide deny "커밋에 에이전트 표기(Co-Authored-By)를 넣지 않는다(CLAUDE.md Git). 메시지에서 그 줄을 빼고 다시 커밋하라."
has "${GIT}tag[[:space:]]+(-d|-f|--delete|--force)[^;&|]*baseline" \
    && decide deny "baseline 태그는 리팩토링 측정 기준점이라 다시 쓰지 않는다."
has "${GIT}(commit[^;&|]*--amend|rebase|reset[[:space:]]+--hard)" \
    && decide ask "이미 push 된 커밋이면 다시 쓰면 안 된다(CLAUDE.md Git). push 전 로컬 커밋인지 확인했는가?"

# ---------- 운영 데이터·볼륨 ----------
has 'docker[^;&|]*[[:space:]]volume[[:space:]]+(rm|prune)' \
    && decide deny "도커 볼륨을 지우지 않는다. DB·MinIO 자격증명과 데이터가 볼륨에 굳어 있다(CLAUDE.md 서버 운영)."
has 'compose[^;&|]*[[:space:]]down[^;&|]*[[:space:]](-v|--volumes)([[:space:]]|$|\\|")' \
    && decide deny "compose down -v 는 볼륨을 지운다. -v 없이 실행하라(CLAUDE.md 서버 운영)."
has 'prune[^;&|]*--volumes' \
    && decide deny "--volumes 정리는 운영 데이터를 지운다(CLAUDE.md 서버 운영)."
has 'rm[[:space:]]+-[[:alpha:]]*[rR][^;&|]*(/home/ubuntu/vintib/?([[:space:]]|$|\\|")|/var/lib/docker)' \
    && decide deny "배포 디렉터리나 도커 데이터 디렉터리를 통째로 지우지 않는다."

# ---------- 비밀값 ----------
has '(cat|less|more|head|tail|bat|type|Get-Content|gc|nano|vi|vim)[[:space:]][^;&|]*\.env([[:space:]]|$|\\|"|'"'"')' \
    && decide deny ".env 내용은 출력하지 않는다. 키 이름만 볼 때는 cut -d= -f1 .env (CLAUDE.md 서버 운영)."
has '(gitlab-runner/config\.toml|\.bash_history)' \
    && decide deny "다른 팀 러너 토큰이 들어 있는 파일이다. 읽거나 고치지 않는다(CLAUDE.md 서버 운영)."
if has 'gitlab-runner' && ! has 'gitlab-runner[[:space:]]+status([[:space:]]|$|\\|")'; then
    decide deny "같은 서버의 다른 팀 GitLab 러너는 건드리지 않는다. 상태 확인(gitlab-runner status)과 docker ps 만 쓴다."
fi

# ---------- 서버 상태 변경(확인 후 진행) ----------
hasi '(drop[[:space:]]+(database|schema|table)|truncate[[:space:]])' \
    && decide ask "DB 객체를 지우거나 비우는 명령이다. 대상이 부하 테스트 데이터뿐인지 확인했는가?"
has 'ufw[[:space:]]+(allow|deny|delete|disable|reset|reject|limit|insert)' \
    && decide ask "방화벽 규칙을 바꾼다. 계획에 근거가 있는가?"
has '(sysctl[[:space:]]+-w|sysctl\.d|systemctl[[:space:]]+(stop|disable|restart|mask)|daemon\.json)' \
    && decide ask "커널·서비스·도커 데몬 설정을 바꾼다. 측정 중이 아니고 계획에 근거가 있는가?"
has 'init-env\.sh' \
    && decide ask "init-env.sh 는 서버에서 처음 한 번만 실행한다. 이미 .env 가 있으면 멈춘다 — 의도한 것인가?"

exit 0
