#!/bin/sh
# Rebuilt from the documented rule set (see docs/test-results.md); order of ufw commands may differ from the live session.
# PAM-GW01 (Teleport Auth + Proxy): only the lab client and the protected host may connect.
set -e
ufw default deny incoming
ufw allow from 192.168.70.1  to any port 443 proto tcp   # PC: tsh + web UI
ufw allow from 192.168.70.30 to any port 443 proto tcp   # TARGET01 agent (reverse tunnel)
ufw allow from 192.168.70.1  to any port 22  proto tcp   # admin SSH (lab convenience, to be removed)
ufw --force enable
