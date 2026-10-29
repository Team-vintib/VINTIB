#!/bin/sh
# 레포를 clone 한 뒤 한 번 실행한다(Git Bash 권장).
#
#   bash setup.sh
#
# Git 훅 경로는 .git/config 에 저장되는데 이 파일은 clone 으로 따라오지 않는다.
# 실행하지 않으면 pull 직후 요청 문서 알림(.githooks/post-merge, post-rewrite)이 동작하지 않는다.
set -e
cd "$(git rev-parse --show-toplevel)"

git config --local core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true

echo "✔ 훅 활성화됨 (core.hooksPath=$(git config --local --get core.hooksPath))"
echo "  pull 직후 새로 생기거나 바뀐 요청 문서를 보여 준다 — docs/README.md"
