# Limitations and roadmap

## Limitations
- AD provides DNS and the domain only; Linux VMs are not domain-joined; Teleport users are local (Community Edition SSO is GitHub only).
- `sysadmin` holds passwordless sudo: standing root for that role, controlled by role assignment, short certificates and audit.
- The `whoami` app does not query PostgreSQL; database isolation is tested at network level.
- GW01 still accepts SSH from the PC (admin convenience); to be removed before final tests.
- Temporary NAT adapters on GW01 and TARGET01 give internet access during setup.
- Firewall tests so far ran from GW01 and the PC, not from an attacker machine.

## Not yet done (not claimed as passed)
- Firewall persistence across a TARGET01 reboot
- Windows Defender Firewall on DC-01 and the PC; outbound filtering; firewall logging
- Wazuh agents, log forwarding and detection rules
- Kali bypass tests and port scan; PostgreSQL probe from an unauthorized machine
- Access revocation and expiry tests
- Clock synchronization check across VMs
