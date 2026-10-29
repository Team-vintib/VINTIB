#!/usr/bin/env bash
# EC2 UFW 라이브 미디어 포트 개방 (S15P11A108-448, 새 서버 k15a306 기준)
#
# LiveKit(OpenVidu v3 미디어 코어)이 브라우저와 직접 주고받는 스트림용 포트다.
# 시그널링(7880)은 열지 않는다 — Caddy 가 443 에서 /rtc·/twirp 로 프록시한다.
#
#   7885/udp  미디어 (UDP mux). infra/livekit/livekit.yaml 의 rtc.udp_port
#   80/tcp    미디어 TCP 폴백. UDP 가 막힌 망의 시청자용. rtc.tcp_port
#             옛 서버는 상위 방화벽이 TCP 22·80·443·8989 만 통과시켜 80 을 미디어에 내줬다(JY012).
#             새 서버는 UDP 7885 가 닿지만, 같은 폴백을 그대로 둔다.
#
# ⚠️ Docker 는 포트 publish 시 iptables 를 직접 조작해 UFW 를 우회한다.
#    즉 compose 가 뜨면 이 두 포트는 UFW 규칙과 무관하게 이미 외부에 열린다.
#    그래도 규칙을 넣는 이유는 **UFW status 가 서버의 실제 개방 상태를 보여주게** 하기
#    위해서다. 여기 없으면 나중에 "왜 이 포트가 열려 있지?" 하고 원인을 못 찾는다.
#
# 멱등: 이미 열려 있으면 ufw 가 중복 추가를 skip 한다.
# 사용법: bash infra/ec2/setup-ufw-media.sh
set -euo pipefail

echo "=== 변경 전 상태 ==="
sudo ufw status verbose

echo
echo "=== 라이브 미디어 포트 추가 ==="
sudo ufw allow 7885/udp comment 'WebRTC media UDP mux - LiveKit'
sudo ufw allow 80/tcp comment 'LiveKit media TCP (JY012)'

echo
echo "=== 변경 후 상태 ==="
sudo ufw status verbose

echo
echo "=== 규칙 확인 ==="
for p in 22 443/tcp 7885/udp 80/tcp; do
    if sudo ufw status | grep -qE "^$p[[:space:]]"; then
        echo "  OK  $p"
    else
        echo "  !!  $p 규칙이 보이지 않음 — 확인 필요"
    fi
done

echo
echo "다음 단계: 컨테이너를 띄운 뒤 실제로 열렸는지 확인한다."
echo "  sudo ss -ulnp | grep 7885"
echo "  sudo ss -tlnp | grep ':80 '"
