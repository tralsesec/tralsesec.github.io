---
layout: project
title: "EnumMSSQL"
status: "ACTIVE"
period: "May 2026 – Present"
language: "Bash / SQL"
field: "Post-Exploitation"
tech: ["Bash", "MSSQL", "T-SQL", "mssqlclient"]
date: 2026-05-17
github: "https://github.com/tralsesec/EnumMSSQL"
---

### Executive Summary
EnumMSSQL is a weaponized, standalone post-exploitation wrapper engineered in Bash to automate the entire MSSQL enumeration and lateral movement lifecycle. Moving far beyond generic script execution, it abstracts away complex T-SQL constraints to provide zero-dependency database auditing, localized pre-flight socket management, and multi-vector hash coercion. Its signature mechanic relies on mathematical, language-agnostic Active Directory user harvesting by establishing an immutable cryptographic anchor inside the target environment.

### Core Architecture
* **Pre-Flight & Interface Engine:** Implements advanced TTY terminal self-healing (stty sane/onlcr) alongside a proactive local socket auditor that scans, maps, and terminates conflicting processes on ports 80, 443, and 445 to guarantee a pristine execution layer.
* **Coercion & Listener Layer:** Chains standalone extended stored procedures (xp_dirtree, xp_subdirs, xp_fileexist) across multiple egress vectors—specifically leveraging WebDAV port 80 encapsulation—to slip past standard enterprise firewall rules while managing an automated background instance of Responder.
* **Enumeration Engine:** Integrates a flawless three-step mathematical query utilizing a recursive Common Table Expression (CTE) loop and bit-shifting logic to reconstruct Little-Endian Windows SIDs, allowing raw user harvesting entirely over low-privilege database connections.

### >> Project Transmissions (Dev Logs)
The following logs document the development milestones, research breakthroughs, and technical hurdles encountered during the EnumMSSQL lifecycle.

| ID | Case Title | Focus | Status | Date |
| :--- | :--- | :--- | :--- | :--- |
{% assign sorted_logs = site.projects | where: "project", "enummssql" | sort: "date" | reverse -%}
{% for log in sorted_logs -%}
  {% if log.url != page.url -%}
| <a href="{{ log.url | relative_url }}">**#{{ forloop.index | prepend: '00' | slice: -3, 3 }}**</a> | <a href="{{ log.url | relative_url }}">**{{ log.title }}**</a> | `{{ log.focus }}` | {{ log.status }} | **{{ log.date | date: "%Y-%m-%d" }}** |
  {% endif -%}
{% endfor %}

### Technical Roadmap
- [x] Pre-flight port audit and automation interface.
- [x] Multi-vector NTLM capture via WebDAV port 80 bypass strings.
- [x] Undocumented procedure abstraction (`sp_MSforeachdb` / `sp_MSforeachtable`) for global data dumping.
- [x] Language-agnostic Active Directory enumeration via `krbtgt` base SID calculation.
- [x] Parameterized --rid scope management with explicit regex input evaluation.
- [ ] Implement multi-threaded parallel execution across massive IP ranges.
- [ ] Integrate deep-nested recursive parsing for automated impersonation chain execution paths.
- [ ] Add standalone JSON export capabilities for programmatic post-processing pipelines.
