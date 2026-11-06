# Test results (observed)

Only observed output is listed as passed. Audit times are UTC (local time Tunis is UTC+1).

## Authorization tests (2026-10-14)

| # | Actor and action | Expected | Observed | Result |
|---|---|---|---|---|
| A1 | `u-infra` logs in (password + OTP) | success, role `infra-admin`, login `sysadmin` | `Logged in as u-infra`, `Roles: infra-admin`, `Logins: sysadmin`, valid 7h59m | Pass |
| A2 | `u-infra`: `tsh ssh sysadmin@pam-target01 "whoami; hostname; sudo -n docker ps"` | allowed | `sysadmin`, `pam-target01`, 3 containers | Pass |
| A3 | `u-appop` logs in | success, role `app-operator` | as expected, valid 1h59m | Pass |
| A4 | `u-appop`: `whoami` on target | allowed as `appop` | `appop` | Pass |
| A5 | `u-appop`: `sudo -n true` | denied | `sudo: a password is required` | Pass |
| A6 | `u-appop`: `docker ps` | denied | `permission denied ... docker.sock` | Pass |
| A7 | `u-appop`: `tsh ssh sysadmin@pam-target01` | denied by Teleport | `access denied to sysadmin connecting to pam-target01` | Pass |
| A8 | `u-limited` logs in, then `tsh ssh appop@pam-target01` | login ok, SSH denied | login ok, empty logins; `access denied to appop connecting to pam-target01` | Pass |

This is a provisional subset; the final RBAC accuracy KPI will be computed on the full test matrix.

## Firewall tests (2026-10-16)

| # | Test | Before | After | Result |
|---|---|---|---|---|
| F1 | GW01 to TARGET01:22 | open | closed/filtered | Pass |
| F2 | GW01 to TARGET01:8080 | open | closed/filtered | Pass |
| F3 | GW01 to TARGET01:5432 | closed/filtered | closed/filtered | Pass (never published) |
| F4 | PC to `http://192.168.70.30:8080` | reply | reply | Pass (allowed source) |
| F5 | PC: new SSH to 192.168.70.30:22 | not run | `Connection timed out` | Pass |
| F6 | PC: `tsh ssh sysadmin@pam-target01 whoami`, direct SSH blocked | works | `sysadmin` | Pass |
| F7 | TARGET01 to GW01:443 / :22 | not run | 443 open, 22 closed/filtered | Pass |
| F8 | restart TARGET01 agent, `tctl nodes ls` | not run | `pam-target01` listed | Pass |
| F9 | PC: `tsh ssh` through GW01 firewall | not run | `sysadmin` | Pass |

Observations:
- An SSH session opened **before** the rules stayed alive (stateful firewall; rules apply to new connections).
- The first "before" baseline was invalid (target powered off) and was repeated.
- After a cold start, `pam-target01` only appeared once DC-01 (DNS) was running.
- Tests ran from GW01 and the PC, not from an attacker machine.

## Audit evidence (Teleport audit log, UTC)

- Failed login logged (`missing second factor`).
- Session start, command execution and session end for `u-infra` on `pam-target01`.
- `Command Execution Failed` for `u-appop` (sudo/docker attempt).
- `Auth Attempt Failed` for `u-appop` as `sysadmin` and for `u-limited` as `appop` (principal not valid).
- A recorded interactive session, replayable, matching its audit event.
