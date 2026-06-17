---
layout: project
title: "EnumSMB"
status: "ACTIVE"
period: "June 2026 – Present"
language: "Bash"
field: "Share Auditing & Post-Exploitation"
tech: ["Bash", "SMB", "smbclient", "Windows"]
date: 2026-06-17
github: "https://github.com/tralsesec/EnumSMB"
---

EnumSMB is a weaponized, standalone wrapper written in Bash to automate the SMB file share auditing lifecycle. Moving beyond generic script execution, it abstracts away complex structural formatting constraints to provide zero-dependency folder auditing, deep-nested path resolution, and multi-vector authentication coercion. Its signature mechanic relies on deep recursive validation loops and embedded layout templates to evaluate background parsing behavior across hidden network layers.

### Core Architecture
* **Pre-Flight & Interface Engine:** Implements automatic non-administrative share mapping (filtering out default endpoints like C\$ and ADMIN\$) alongside path healing routines that strip carriage returns and trailing backslashes to safeguard subshell execution.
* **Coercion & Ingestion Layer:** Chains embedded template engines across multiple desktop shell and XML storage structures (including .url, .scf, and .library-ms) to inject context-aware variables like attacker IPs and custom share handles dynamically on the fly.
* **Enumeration Engine:** Integrates safe, non-destructive probing using operational mkdir/rmdir loops to explicitly map actual read/write access states deep within tree hierarchies rather than trusting superficial share-level flags.

### Technical Roadmap
- [x] Automated target scope selection and administrative share filtering.
- [x] Deep-nested tree traversal via recursive parsing loops.
- [x] Operational non-destructive verification checks (mkdir/rmdir loops).
- [x] Integrated basic multi-vector coercion templates (.url, .scf, .library-ms, .search-ms, .searchConnector-ms, .search).
- [x] Dynamic parameter interfacing with automated variable expansion ($USER_IP, $SHARE).
- [x] Global multi-extension sweep capability for post-engagement clean mode (.background-image.*).
- [ ] Integrate advanced binary shortcut and disk container formats (.lnk, .vhd, .vhdx, .iso).
- [ ] Add Microsoft Office template and unmanaged add-in vector extensions (.xll, .dot, .dotm, .dotx).
- [ ] Implement multi-threaded parallel target scanning across massive network blocks.
