# PAM Project: Evidence Log (state at 2026-10-14, ~12:10 local)

Rule for this file: only observed output goes under "Observed". Anything not run is listed under "Not yet tested".
Times in Teleport's audit log are UTC; local time (Tunis) is UTC+1.

## 1. Lab as built (observed)

| Machine | Role | Address | OS / version | Evidence |
|---|---|---|---|---|
| PAM-DC01 | AD DS + DNS, domain `pam.lab` (NetBIOS `PAM`, Windows2016Domain) | 192.168.70.10/24 static, DNS client 127.0.0.1 | Windows Server 2022 Standard Evaluation | PowerShell: DomainRole 5, NTDS/DNS/Kdc/W32Time Running, Dhcp Disabled |
| PAM-GW01 | Teleport Community Edition (Auth + Proxy), PAM gateway | 192.168.70.20/24 (ens33) + NAT 192.168.111.143 (ens37, temporary) | Ubuntu 24.04.4 LTS, kernel 6.8.0-100, 1.8 GiB RAM | `teleport version` v18.11.3; Proxy answers on 443 with lab-CA certificate |
| PAM-TARGET01 | Protected Linux host, Docker services | 192.168.70.30/24 (ens33) + NAT 192.168.111.144 (ens34, temporary) | Ubuntu 24.04, Docker 29.1.3, Compose 2.40.3 | `docker compose ps`, `ss -tlnp` |
| Windows host (PC) | Authorized client (`tsh` v18.11.3), future Wazuh host | 192.168.70.1/24 on VMnet1 | Windows 11 | `Get-NetIPAddress`, ping 4/4 to DC-01 |
| Kali | Unauthorized test client | not confirmed | not confirmed | availability still unknown |

Network: VMware VMnet1, Host-only, 192.168.70.0/24, VMware DHCP disabled. Addresses above are the ones we assigned and verified.

## 2. Steps performed and where (no secrets recorded)

1. DC-01: inspected domain state, IP, DNS client, services (all read-only). Added DNS A record `pam-gw01.pam.lab -> 192.168.70.20` (`Add-DnsServerResourceRecordA`).
2. Host PC: set VMnet1 adapter to static 192.168.70.1/24 (it was 169.254.x.x); added a narrow inbound ICMP rule for 192.168.70.0/24 on the VMnet1 adapter; hosts-file entry for `pam-gw01.pam.lab`; imported the lab CA into the current-user trusted roots.
3. GW01: static IP via installer, NAT adapter added with a separate netplan file (`/etc/netplan/60-nat.yaml`), Teleport 18.11.3 installed from the official apt repository via the vendor script (script SHA-256 check printed OK).
4. GW01: created a lab CA and a server certificate for `pam-gw01.pam.lab` (SAN: DNS + IP 192.168.70.20) with openssl; `openssl verify` printed OK; CA added to the system trust store.
5. GW01: `teleport configure` with that certificate, service started, HTTPS ping answered without `-k` (local auth, second factor `otp`).
6. TARGET01: static IP via installer, Docker installed (Ubuntu packages `docker.io`, `docker-compose-v2`), user NOT added to the `docker` group.
7. TARGET01: Compose project with 3 containers (nginx, traefik/whoami, postgres:16). Nginx published on 192.168.70.30:8080 only; PostgreSQL not published; backend network `internal`.
8. TARGET01: joined to Teleport as a node (`pam-target01`, labels `env=lab,role=docker-host`) with a 15-minute token; outbound reverse tunnel.
9. TARGET01: Linux users `sysadmin` (passwordless sudo, no password for login) and `appop` (no sudo, not in docker group), both with locked passwords.
10. GW01: Teleport roles `infra-admin` (login sysadmin, 8h TTL), `app-operator` (login appop, 2h TTL), `limited-user` (no logins, 2h TTL); users `pam-admin` (editor, auditor; no SSH), `u-infra`, `u-appop`, `u-limited`; all with TOTP MFA.
11. Host PC: `tsh` v18.11.3 downloaded; archive SHA-256 matched the vendor's published value (4f285239...f8a9).

## 3. Observed results

### 3.1 Teleport licence and edition (from official docs, consulted 2026-10-14)
- Community Edition licence since v16: free for individuals; companies under 100 employees and under $10MM annual revenue. A student lab fits (our reading, not a legal opinion).
- Feature matrix: SSO in CE is GitHub only; OIDC, SAML, Entra ID, Okta are Enterprise. The FAQ states authentication via OIDC, SAML or Active Directory is offered in Enterprise editions. => Therefore no AD login and no Keycloak SSO in this project; identities in Teleport are local users.
- Just-in-time access requests in CE: CLI only (no graphical approval workflow).

### 3.2 Authorization tests (observed output)

| # | Actor and action | Expected | Observed | Result |
|---|---|---|---|---|
| A1 | u-infra logs in (password + OTP) | success, role infra-admin, login sysadmin | `Logged in as u-infra`, `Roles: infra-admin`, `Logins: sysadmin`, valid 7h59m | Pass |
| A2 | u-infra: `tsh ssh sysadmin@pam-target01 "whoami; hostname; sudo -n docker ps"` | allowed | `sysadmin`, `pam-target01`, 3 containers listed | Pass (this is report test T02) |
| A3 | u-appop logs in | success, role app-operator, login appop | as expected, valid 1h59m | Pass |
| A4 | u-appop: `whoami` on target | allowed as appop | `appop` | Pass |
| A5 | u-appop: `sudo -n true` | denied | `sudo: a password is required` | Pass (T03) |
| A6 | u-appop: `docker ps` | denied | `permission denied ... docker.sock` | Pass (T05) |
| A7 | u-appop: `tsh ssh sysadmin@pam-target01` | denied by Teleport | `access denied to sysadmin connecting to pam-target01` | Pass |
| A8 | u-limited logs in, then `tsh ssh appop@pam-target01` | login ok, SSH denied | login ok, empty Logins; `access denied to appop connecting to pam-target01` | Pass |

Provisional authorization decisions: 8 steps above, of which 7 are authorization decisions about access (A2, A4, A5, A6, A7, A8 plus the allowed login mapping in A1/A3); all matched the expected outcome. The final RBAC accuracy KPI is computed over the final test matrix, not over this partial set.

Note on A5/A6: these denials come from Linux permissions on TARGET01. Teleport's contribution is restricting which Linux account each role may use (A7, A8).

### 3.3 Audit evidence (Teleport audit log, UTC)
- 10:57:46 `Local Login Failed [missing second factor]` (u-infra), my own mistyped OTP; shows failed authentication is logged.
- 10:59:52 Session Started / 11:00:03 Command Execution / 11:00:05 Session Ended, u-infra on pam-target01.
- 11:01:28 `Command Execution Failed [exit status 1]`, u-appop (the sudo/docker attempt).
- 11:02:02 `Auth Attempt Failed`: u-appop, principal "sysadmin" not in the valid principals ["appop" ...].
- 11:02:59 `Auth Attempt Failed`: u-limited, principal "appop" not in the valid principals (only a nologin principal).
- 11:04:21 to 11:04:51: interactive session of u-infra, Session Started, Session Ended (17 s), Session Uploaded.
- Session recording ID bab664dd-5180-4704-bee2-705bad45eec8 appears both in the audit log and in the recording (commands `whoami`, `sudo docker ps` visible).
- Setup events also logged: user creation, password-reset tokens, MFA device added (all three users), certificate issuance.
- Clock: recording time (12:04 local) equals audit time (11:04 UTC), so GW01 and the PC agree.

### 3.4 Docker services (TARGET01)
- `docker compose ps`: web, app, db all Up.
- `curl http://192.168.70.30:8080` returned the whoami reply through Nginx.
- `ss -tlnp | grep -E ':8080|:5432'`: only `192.168.70.30:8080` (docker-proxy); no listener for 5432.
- db shows `5432/tcp` without a host mapping.

### 3.5 Firewall (applied 2026-10-16, observed output)

Rules on TARGET01 (ufw + Docker `DOCKER-USER` chain, because Docker-published ports bypass ufw INPUT rules):
- ufw: `Status: active`, `Default: deny (incoming), allow (outgoing)`; no allow rule for SSH.
- DOCKER-USER (listing with `-n -v`): 1) RETURN tcp from 192.168.70.1, dport 8080, in ens33; 2) DROP in ens33; 3) RETURN. Rebuilt at boot by `docker-user-fw.service` (installed and enabled; reboot test still to do).

Rules on GW01 (ufw): default deny incoming; allow 443/tcp from 192.168.70.1 (PC) and 192.168.70.30 (TARGET01); allow 22/tcp from 192.168.70.1 only.

| # | Test | Before | After | Result |
|---|---|---|---|---|
| F1 | GW01 -> TARGET01:22 (TCP connect) | OPEN | closed/filtered | Pass |
| F2 | GW01 -> TARGET01:8080 | OPEN | closed/filtered | Pass |
| F3 | GW01 -> TARGET01:5432 | closed/filtered | closed/filtered | Pass (never published) |
| F4 | PC -> http://192.168.70.30:8080 | reply | reply (`Hostname: ...`) | Pass (allowed source) |
| F5 | PC -> new SSH to 192.168.70.30:22 | not run | `Connection timed out` | Pass |
| F6 | PC -> `tsh ssh sysadmin@pam-target01 whoami` with direct SSH blocked | works | `sysadmin` | Pass (PAM path intact, tunnel is outbound from the target) |
| F7 | TARGET01 -> GW01:443 / :22 after GW01 firewall | not run | 443 OPEN, 22 closed/filtered | Pass |
| F8 | TARGET01 Teleport agent restarted, then `tctl nodes ls` | not run | `pam-target01` listed | Pass |
| F9 | PC -> `tsh ssh` through the GW01 firewall (new session over 443) | not run | `sysadmin` | Pass |

Observations to keep honest:
- An SSH session from the PC that was already open before the rules were applied stayed alive (stateful firewall: rules apply to new connections). Close it before demonstrating F5.
- First baseline attempt was invalid (TARGET01 was powered off) and was repeated; the valid "before" values are in the table above.
- After a cold start, `pam-target01` was missing from `tctl nodes ls` until DC-01 (DNS) was running; it reconnected afterwards. The firewall must therefore keep DNS to DC-01 available, and AD/DNS is a real dependency of the Teleport agent path (the agent connects by name).
- GW01 still accepts SSH from the PC (a direct administration path outside Teleport); documented trade-off, to be removed before the final tests if not needed.
- Not yet verified: persistence across a TARGET01 reboot, outbound filtering (outgoing is allow-all), DNS rule on the Windows side, firewall logging in Wazuh.

## 4. Issues met and fixes (for the report's limits/lessons section)
- VMnet1 host adapter had a 169.254.x.x address; fixed with a static address.
- First pings failed until the address left the Tentative state; GW01-to-host ping needed a Windows Firewall rule (inbound ICMP from the lab subnet, VMnet1 adapter only).
- NAT adapter needed its own netplan file on GW01 (interface `ens37`).
- `teleport configure` first failed because the certificate files were in the home folder, not `/var/lib/teleport`; the service looped until the files were moved and the config regenerated.
- One DNS lookup timeout for `pam-gw01.pam.lab` on TARGET01 at start-up, resolved on retry (agent connected 13 s later). DNS to DC-01 must stay allowed by the firewall.
- Linux user creation was first run on GW01 by mistake; removed there, redone on TARGET01.
- OTP prompt was submitted empty once (`missing second factor`).

## 5. Known limits and design trade-offs (state honestly in the report)
- AD provides DNS and the domain only; Linux VMs are not domain-joined; Teleport uses local users. Any AD group to Teleport role mapping would be manual, not an integration.
- GW01 (Teleport) and TARGET01 (protected resource) are separate VMs, as the report recommends; the lab CA private key sits on GW01 (lab convenience).
- `sysadmin` has passwordless sudo: standing root for that role; control is Teleport role assignment plus audit.
- The app container is `traefik/whoami`; it does not query PostgreSQL, so DB reachability is tested at network level and via `psql` inside the container.
- Docker packages come from Ubuntu's repositories (older than Docker's own repo).
- The host PC trusts the lab CA in the current-user store; remove it at the end of the project.
- GW01 and TARGET01 still have a temporary NAT adapter (internet access); it must be removed or blocked before the firewall tests.

## 6. Not yet tested or done (do NOT report as passed)
- Firewall persistence across a TARGET01 reboot; Windows Defender Firewall on DC-01 and the PC; outbound filtering; firewall logging (T17); formal T18 regression across AD/DNS, Teleport and Wazuh.
- Firewall tests F1 to F9 (section 3.5) were run from GW01 and the PC, not from Kali; Kali availability is still unconfirmed. A full port scan (T16) has not been run.
- PostgreSQL isolation from an external source (T14) is only checked from GW01 (port closed/filtered), not with a client from an unauthorized machine.
- Wazuh: Docker Desktop was not running when checked; no agents installed; no log forwarding.
- Revocation/expiry behaviour (to be checked against the Teleport docs first).
- Details of some audit events (command text, source IP, four `Certificate Issued` events for u-limited at 11:00:27 UTC): to be inspected.
- Time synchronization of TARGET01 and DC-01 not yet checked.

## 7. Screenshots to keep (tick when saved)
- [ ] DC-01: domain, IP, services output
- [ ] Host: VMnet1 address and ping
- [ ] GW01: `teleport version`, `curl` ping result (trusted TLS)
- [ ] TARGET01: `docker compose ps`, `ss` output
- [ ] `tctl nodes ls` (both nodes)
- [ ] u-infra login + A2 output
- [ ] u-appop outputs (A5, A6, A7)
- [ ] u-limited outputs (A8)
- [ ] Audit log page, the denied attempts, session recording replay
