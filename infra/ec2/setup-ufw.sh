#!/usr/bin/env bash
# EC2 UFW 웹 포트 개방 (S15P11A108-297, 새 서버 k15a306 기준)
#
#   22       SSH. UFW 를 켜기 전에 반드시 열려 있어야 접속이 끊기지 않는다
#   443/tcp  HTTPS — Caddy. 인증서도 443 에서 TLS-ALPN-01 로 받는다(80 은 LiveKit 미디어가 쓴다, JY012)
#   443/udp  HTTP/3 — Caddy. 캠퍼스 상위 방화벽이 UDP 443 을 막아 지금은 쓰이지 않지만 열어 둔다
#
# 라이브 미디어 포트(80/tcp, 7885/udp)는 setup-ufw-media.sh 가 연다.
#
# 멱등: 이미 있는 규칙은 ufw 가 skip 한다. UFW 가 꺼져 있으면 켜지 않고 알려만 준다.
# 사용법: bash infra/ec2/setup-ufw.sh
set -euo pipefail

echo "=== 변경 전 상태 ==="
sudo ufw status verbose

echo
echo "=== 웹 포트 추가 ==="
sudo ufw allow 22
sudo ufw allow 443/tcp comment 'HTTPS - Caddy'
sudo ufw allow 443/udp comment 'HTTP/3 - Caddy'

echo
echo "=== 변경 후 상태 ==="
sudo ufw status verbose

echo
echo "=== 필수 규칙 확인 ==="
for p in 22 443/tcp 443/udp; do
    if sudo ufw status | grep -qE "^$p[[:space:]]"; then
        echo "  OK  $p"
    else
        echo "  !!  $p 규칙이 보이지 않음 — 확인 필요"
    fi
done

if ! sudo ufw status | grep -q '^Status: active'; then
    echo
    echo "UFW 가 꺼져 있다. 22 가 허용된 것을 확인한 뒤 직접 켠다: sudo ufw enable"
fi
