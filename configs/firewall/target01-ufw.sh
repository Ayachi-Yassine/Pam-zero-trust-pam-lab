#!/bin/sh
# PAM-TARGET01: default-deny inbound (closes direct SSH), outbound allowed
# (the Teleport agent opens an outbound reverse tunnel to the Proxy).
# Docker-published ports bypass ufw INPUT rules, so Nginx is restricted in DOCKER-USER
# by docker-user-fw.service (install it first).
# Safety net used during the lab: a 15-minute rollback timer, cancelled after validation:
#   systemd-run --on-active=15m --unit=fw-rollback /bin/sh -c 'ufw disable; iptables -F DOCKER-USER'
#   systemctl stop fw-rollback.timer
set -e
ufw default deny incoming
ufw default allow outgoing
ufw --force enable
