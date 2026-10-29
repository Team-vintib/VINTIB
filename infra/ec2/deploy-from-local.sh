#!/usr/bin/env bash
# 로컬(Git Bash)에서 EC2 로 커밋 하나를 배포한다 — GitLab 러너 없이 측정 라운드마다 다시 배포하기 위한 스크립트.
#
#   bash infra/ec2/deploy-from-local.sh                 # HEAD 를 배포
#   REF=baseline bash infra/ec2/deploy-from-local.sh    # 태그·커밋 지정
#   PREPARE_ONLY=1 bash infra/ec2/deploy-from-local.sh  # 코드만 올리고 빌드·기동은 안 함(DB 복원 전)
#
# CI 배포(infra/ci/deploy.sh)와 같은 순서를 따른다: 코드 동기화 → 빌드 → 기동 → Caddy 반영 확인
# → 헬스체크 → 실패 시 직전 태그 롤백. 다른 점은 두 가지다.
#   1) .env 를 만들지 않는다. 서버에 init-env.sh 로 한 번 만들어 둔 것을 그대로 쓰고 IMAGE_TAG 만 바꾼다.
#   2) 저장소 전체가 아니라 git archive 로 **커밋된 내용만**, AI/validation·worker 를 빼고 보낸다
#      (추적 파일 ~490MB → ~12MB). 작업 트리의 커밋 안 된 변경은 배포되지 않는다.
#
# 배포 소요 시간(빌드·교체·헬스)을 마지막에 출력한다 — 베이스라인 지표 "배포 소요 / 다운타임"의 원천이다.
set -euo pipefail

HOST=${HOST:-k15a306.p.ssafy.io}
KEY=${KEY:-$HOME/.ssh/K15A306T.pem}
REF=${REF:-HEAD}
DEPLOY_DIR=/home/ubuntu/vintib
PREPARE_ONLY=${PREPARE_ONLY:-0}

cd "$(git rev-parse --show-toplevel)"
TAG=$(git rev-parse --short "$REF")
SSH_OPTS=(-i "$KEY" -o BatchMode=yes -o ConnectTimeout=15)

if [ "$REF" = "HEAD" ] && ! git diff --quiet HEAD -- BE infra docker-compose.yml docker-compose.prod.yml 2>/dev/null; then
    echo "[deploy] !! BE/infra/compose 에 커밋 안 된 변경이 있다 — 배포되는 것은 커밋 $TAG 뿐이다"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "[deploy] $REF($TAG) 압축"
# ⚠️ core.autocrlf=false 를 강제한다. Windows 기본값(true)이면 git archive 가 Dockerfile·yml 등을
#    CRLF 로 내보내고, 리눅스에서 \r 이 붙은 명령이 조용히 깨진다(.gitattributes 는 *.sh 만 LF 고정).
git -c core.autocrlf=false archive --format=tar.gz -o "$work/src.tgz" "$REF" -- . \
    ':(exclude)AI/validation' ':(exclude)worker'
ls -la "$work/src.tgz" | awk '{print "[deploy] 크기 " $5 " bytes"}'

echo "[deploy] 업로드 → $HOST"
scp "${SSH_OPTS[@]}" "$work/src.tgz" "ubuntu@$HOST:/tmp/vintib-src.tgz"

ssh "${SSH_OPTS[@]}" "ubuntu@$HOST" \
    "TAG='$TAG' DEPLOY_DIR='$DEPLOY_DIR' PREPARE_ONLY='$PREPARE_ONLY' bash -s" <<'REMOTE'
set -euo pipefail
log() { echo "[remote] $*"; }
now() { date +%s; }

COMPOSE="sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml -p vintib"
HEALTH_TIMEOUT=240

# ---------- 1. 코드 동기화 ----------
staging=$(mktemp -d)
tar xzf /tmp/vintib-src.tgz -C "$staging"
mkdir -p "$DEPLOY_DIR"
# .env 는 서버 전용 비밀값, _disabled 는 격리한 override, perf 는 서버에서 만든 측정 산출물이다.
rsync -a --delete --exclude '.env' --exclude '_disabled' --exclude 'perf-out' "$staging/" "$DEPLOY_DIR/"
rm -rf "$staging" /tmp/vintib-src.tgz
if [ -f "$DEPLOY_DIR/docker-compose.override.yml" ]; then
    mkdir -p "$DEPLOY_DIR/_disabled"
    mv "$DEPLOY_DIR/docker-compose.override.yml" "$DEPLOY_DIR/_disabled/docker-compose.override.yml.disabled"
    log "override 격리"
fi
log "코드 동기화 완료 ($TAG)"

if [ "$PREPARE_ONLY" = "1" ]; then
    log "PREPARE_ONLY — 빌드·기동 생략"
    exit 0
fi

cd "$DEPLOY_DIR"
[ -f .env ] || { log "!! .env 가 없다 — infra/ec2/init-env.sh 를 먼저 실행한다"; exit 1; }

PREVIOUS_TAG=$(grep '^IMAGE_TAG=' .env | cut -d= -f2 || true)
sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$TAG/" .env
log "태그 $PREVIOUS_TAG → $TAG"

# ---------- 2. 빌드 ----------
t0=$(now)
$COMPOSE build
t1=$(now)

# ---------- 3. 교체 ----------
$COMPOSE up -d
t2=$(now)

# ---------- 4. Caddy 설정 반영 (deploy.sh 와 같은 이유: bind mount inode, -514) ----------
HOST_SUM=$(md5sum infra/caddy/Caddyfile | cut -d' ' -f1)
CTR_SUM=$(sudo docker exec vintib-caddy md5sum /etc/caddy/Caddyfile 2>/dev/null | cut -d' ' -f1 || true)
if [ "$HOST_SUM" != "$CTR_SUM" ]; then
    sudo docker restart vintib-caddy >/dev/null && log "Caddy 재시작(설정 불일치)"
elif sudo docker exec vintib-caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; then
    log "Caddy reload"
else
    log "!! Caddy reload 실패 — 옛 설정으로 계속 돈다"
fi

# ---------- 5. 헬스체크 ----------
healthy=""
status=none
while [ $(( $(now) - t2 )) -lt "$HEALTH_TIMEOUT" ]; do
    status=$(sudo docker inspect -f '{{.State.Health.Status}}' vintib-backend 2>/dev/null || echo none)
    [ "$status" = "healthy" ] && { healthy=yes; break; }
    sleep 3
done
t3=$(now)

if [ -z "$healthy" ]; then
    log "!! 헬스체크 실패 (backend: $status)"
    sudo docker logs --tail 60 vintib-backend 2>&1 || true
    if [ -n "$PREVIOUS_TAG" ] && [ "$PREVIOUS_TAG" != "$TAG" ] && [ "$PREVIOUS_TAG" != "init" ]; then
        sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$PREVIOUS_TAG/" .env
        $COMPOSE up -d
        log "직전 태그 $PREVIOUS_TAG 로 롤백"
    fi
    exit 1
fi

$COMPOSE ps --format 'table {{.Name}}\t{{.Status}}'
sudo docker image prune -f >/dev/null 2>&1 || true
log "배포 성공 — build $((t1 - t0))s / up $((t2 - t1))s / healthy $((t3 - t2))s / 합계 $((t3 - t0))s"
REMOTE
