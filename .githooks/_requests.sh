#!/bin/sh
# pull 직후 "이번에 새로 생기거나 바뀐 요청 문서"를 터미널에 보여 준다.
# post-merge(git pull 기본)와 post-rewrite(git pull --rebase)가 함께 쓴다.
#
# 요청 문서의 상태 원본은 각 문서 머리의 "- 상태:" 줄이다(docs/requests/README.md).
# 팀 시절 문서(docs/requests/<파트>/…)는 기록용이라 보지 않는다 — 바로 아래 파일만 본다.

show_changed_requests() {
    from=$1
    to=${2:-HEAD}
    git rev-parse -q --verify "$from" >/dev/null 2>&1 || return 0

    files=$(git -c core.quotepath=false diff --name-only --diff-filter=AM "$from" "$to" -- \
        ':(glob)docs/requests/*.md' ':(exclude)docs/requests/README.md' ':(exclude)docs/requests/_template.md')
    [ -z "$files" ] && return 0

    printf '\n[요청 문서] 이번 pull로 새로 생기거나 바뀐 문서\n'
    echo "$files" | while IFS= read -r f; do
        [ -f "$f" ] || continue
        title=$(sed -n '1s/^# *//p' "$f")
        status=$(sed -n 's/^- 상태: *//p' "$f" | head -n 1)
        who=$(sed -n 's/^- 요청: *//p' "$f" | head -n 1)
        printf '  [%s] %s  (%s)\n        %s\n' "${status:-?}" "$title" "${who:-?}" "$f"
    done

    open=0
    for f in docs/requests/*.md; do
        case "$f" in */README.md|*/_template.md) continue ;; esac
        grep -q '^- 상태: *요청' "$f" 2>/dev/null && open=$((open + 1))
    done
    printf '[요청 문서] 답을 기다리는 요청 %s건 — docs/requests/README.md\n\n' "$open"
}
