# Red-Team Study Checklist (High-Level, Non-Actionable)
**Purpose:** learning roadmap for understanding attacker techniques and defensive countermeasures — *no exploit code included*.

## Ethics & Safe Practice
- Only test systems you own or have explicit permission to test.
- Use isolated labs (VM snapshots) and follow platform rules (TryHackMe, Hack The Box).
- Keep detailed logs and legal consent for any engagement.

## Topics (learning order)
1. **Foundations**: TCP/IP, routing, Linux/macOS internals, Windows basics
2. **Enumeration**: service discovery, port scanning, banner analysis (theory + detection)
3. **Vulnerabilities 101**: CVE lifecycle, patching, and common vulnerability classes (RCE, XSS, CSRF)
4. **Privilege Escalation (theory)**: SUID/SGID, sudo misconfigurations, credential/credential stores — learn *defenses*, not exploit steps
5. **Persistence & Evasion (theory)**: cron jobs, startup agents, anomalous services — detection + mitigation
6. **Lateral Movement (theory)**: authentication delegation, SSH keys, network segmentation — focus on hardening
7. **Logging & Monitoring**: SIEM basics, log collection, alert tuning, EDR concepts
8. **Forensics Basics**: file timeline analysis, memory capture theory, evidence preservation
9. **Red-Team Tools (study list)**: LinPEAS (read-only study), BloodHound (graph theory), Adversary Emulation frameworks — read docs & defensive mappings
10. **Cobalt Strike / Emulation (theory only)**: understand concepts, do not use unauthorized tools

## Defensive Mapping (how offensive techniques map to detections)
- **Port Scans / Recon** → Detection: high-rate SYN/connection attempts, IDS/IPS alerts, rare source IPs
- **SUID Abuse** → Detection: new/changed SUID binaries, unexpected owner changes, file integrity hashes
- **Cron / Startup Persistence** → Detection: new crontab entries, unknown launch agents, timestamp anomalies
- **Lateral Movement (SSH keys)** → Detection: new authorized_keys, unusual SSH logins, key fingerprints changes
- **Credential Theft** → Detection: abnormal access to secret stores, high-volume file reads, new processes accessing /etc/shadow or keyring locations
- **Malicious Containers** → Detection: unknown container images, outbound connections from containers, new container runtimes

## Labs & Practice (legal)
- TryHackMe: structured rooms for beginners→intermediate
- Hack The Box: realistic labs (use safe lab subnets)
- Metasploitable / Vuln VM images: isolated in local VM networks with snapshots
- Build a lab: Controller machine + target VMs + a snapshot policy before tests

## Learning Resources
- “The Practice of Network Security Monitoring” — practical monitoring tactics
- Linux hardening guides (CIS Benchmarks)
- Vendor docs: Microsoft, Apple, major Linux distros for secure defaults
- Project documentation: LinPEAS, Osquery, Wazuh (for defensive study)

## Ethics Reminder
Always have permission. Use your skills to defend, not to harm.
