#!/usr/bin/env bash
# PreToolUse 가드 — Write·Edit 대상 파일.
#
# 루트 세션은 BE·인프라·문서를 다룬다(루트 CLAUDE.md 파트 사이 규칙). 다른 파트 기능 코드나 규칙 자체를
# 바꾸는 파일을 고치려 하면 사람에게 확인을 받는다(ask). 막지는 않는다 — 그 파트가 요청한 변경이나
# 배포 구성처럼 정당한 경우가 있다.
input=$(cat)
f=$(printf '%s' "$input" | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n 1)
[ -z "$f" ] && exit 0
# JSON 이스케이프된 Windows 경로(C:\\a\\b)를 슬래시로 바꾼다.
p=$(printf '%s' "$f" | sed 's#\\\\#/#g; s#\\#/#g')

ask() {
    reason=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason"
    exit 0
}
on() { printf '%s' "$p" | grep -Eqi -- "$1"; }

on '(^|/)(FE/src|AI/app|AI/worker)/' \
    && ask "FE·AI·worker 기능 코드다. 다른 파트 코드는 직접 고치지 않는다(CLAUDE.md 파트 사이 규칙). 그 파트가 요청한 변경이나 배포 구성이 아니라면 멈춘다."
on '(^|/)\.claude/(hooks/|settings\.json$)' \
    && ask "에이전트 가드·권한 설정 자체를 바꾼다. 사용자가 요청한 변경인가?"

exit 0
