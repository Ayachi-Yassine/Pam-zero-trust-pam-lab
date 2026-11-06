# Roles and permissions

Roles are defined in [`configs/teleport/roles.yaml`](../configs/teleport/roles.yaml). Each role matches only nodes labelled `env: lab`. Teleport restricts **which Linux account** a role can use; `sudo` and `docker` denials come from Linux permissions on the target.

| Role | User | Linux login | Max cert TTL | Can | Cannot |
|---|---|---|---|---|---|
| `infra-admin` | `u-infra` | `sysadmin` (passwordless sudo) | 8 h | SSH via Teleport; `sudo`; `docker ps` through sudo | administer Teleport; reach the host outside Teleport |
| `app-operator` | `u-appop` | `appop` (no sudo, no docker group) | 2 h | SSH as `appop`; `whoami` and unprivileged commands | `sudo`; `docker`; log in as `sysadmin` |
| `limited-user` | `u-limited` | none | 2 h | log in (password + OTP) | SSH as any account |
| `pam-admin` | `pam-admin` | none | n/a | administer Teleport (`editor`), read audit and recordings (`auditor`) | SSH; no resource is visible to it |

All users authenticate with password + TOTP.
