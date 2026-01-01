---
layout: project
title: "ATP C2 – Custom Command & Control Infrastructure"
status: "ARCHIVED"
period: "Aug 2023 – Dec 2023"
language: "C++, ASM, PowerShell"
field: "Red Teaming & Evasion"
tech: ["C++", "C2", "Malware Dev", "EDR Evasion", "Windows Internals"]
date: 2023-08-01
---

Designed and implemented a custom Command & Control (C2) infrastructure to simulate sophisticated adversary behavior in controlled environments.

### Tactical Implementation

* **Evasion Techniques:** Developed a C++ implant featuring in-memory execution and advanced obfuscation to bypass static signature detection and dynamic analysis of enterprise AV/EDR solutions.
* **Custom Protocol:** Engineered an encrypted communication protocol over HTTPS to blend C2 traffic with legitimate network noise, minimizing the probability of discovery during beaconing.
* **Operational Objective:** Built to understand the offensive lifecycle and improve detection engineering capabilities (Purple Teaming) by analyzing the artifacts left behind by custom implants.



### Knowledge Gained
This project served as a deep dive into **Windows Internals**, specifically focusing on how modern defensive solutions hook APIs and how those hooks can be bypassed or avoided through direct system calls and manual mapping.
