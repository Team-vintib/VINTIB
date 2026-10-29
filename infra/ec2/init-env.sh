#!/usr/bin/env bash
# 새 서버에서 운영 .env 를 **처음 한 번** 만든다. EC2 위에서 실행한다.
#
#   bash infra/ec2/init-env.sh <도메인> <공인 IP>
#   예) bash infra/ec2/init-env.sh k15a306.p.ssafy.io 13.124.28.159
#
# 비밀값(DB·JWT·MinIO·LiveKit·워커 키)은 여기서 무작위로 만들고 서버 밖으로 내보내지 않는다.
# 이미 .env 가 있으면 멈춘다 — DB·MinIO 자격증명은 볼륨을 처음 만들 때의 값으로 굳기 때문에,
# 덮어쓰면 기존 볼륨에 붙지 못한다(infra/ci/deploy.sh 주석 참고).
#
# 외부 서비스 키(메일·토스·구글·배송조회·GMS)는 비워 둔다. 각각 해당 기능만 실패하고 기동은 된다.
# 필요해지면 .env 에 직접 채우고 backend 를 다시 띄운다.
set -euo pipefail

DOMAIN=${1:?usage: init-env.sh <도메인> <공인 IP>}
NODE_IP=${2:?usage: init-env.sh <도메인> <공인 IP>}
DEPLOY_DIR=${DEPLOY_DIR:-/home/ubuntu/vintib}
ENV_FILE="$DEPLOY_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    echo "이미 $ENV_FILE 가 있다 — 덮어쓰지 않는다(볼륨 자격증명이 어긋난다)"
    exit 1
fi

hex() { openssl rand -hex "$1"; }

mkdir -p "$DEPLOY_DIR"
umask 077
cat > "$ENV_FILE" <<ENV
DB_NAME=vintib
DB_USERNAME=postgres
DB_PASSWORD=$(hex 24)
JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')
SPRING_PROFILES_ACTIVE=prod
SERVER_PORT=8080
IMAGE_TAG=init
WORKER_API_KEY=$(hex 32)
CORS_ALLOWED_ORIGINS=https://$DOMAIN
MINIO_ROOT_USER=vintib$(hex 4)
MINIO_ROOT_PASSWORD=$(hex 24)
MAIL_USERNAME=
MAIL_PASSWORD=
AWS_S3_PUBLIC_ENDPOINT=https://$DOMAIN
SITE_DOMAIN=$DOMAIN
PUBLIC_BASE_URL=https://$DOMAIN
OPENVIDU_API_KEY=vintib$(hex 6)
OPENVIDU_API_SECRET=$(hex 32)
OPENVIDU_SERVER_URL=wss://$DOMAIN
OPENVIDU_API_URL=http://livekit:7880
LIVEKIT_NODE_IP=$NODE_IP
DELIVERY_API_KEY=
DELIVERY_API_SECRET_KEY=
DELIVERY_API_ENDPOINT_ID=
DELIVERY_API_WEBHOOK_SECRET=
TOSS_SECRET_KEY=
TOSS_CLIENT_KEY=
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=
REDIS_PASSWORD=
GMS_API_KEY=
PRICING_COMPS_SOURCE=mock
PRICING_ATTRIBUTE_EXTRACTOR=regex
ENV

echo "생성: $ENV_FILE ($(wc -l < "$ENV_FILE") 줄, 권한 $(stat -c %a "$ENV_FILE"))"
