---
layout: project
title: "Revenant – The Lucid Execution Engine"
status: "ACTIVE"
period: "Dec 2025 – Present"
language: "Rust / LLVM"
field: "Malware Research"
tech: ["Rust", "LLVM", "Compiler Internals", "DBT", "AArch64", "x86_64"]
date: 2025-12-01
github: "https://github.com/Revenant-Engine"
---

### Executive Summary
Revenant is a high-performance Dynamic Binary Translation (DBT) framework engineered in Rust. It specializes in the automated deobfuscation of polymorphic and metamorphic malware by lifting opaque binary blobs into **LLVM Intermediate Representation (IR)**. Unlike standard emulators, Revenant focuses on semantic recovery—stripping away junk code and mutation layers to reveal the underlying logic.

### Core Architecture
* **Front-end (Lifting):** Supports x86_64 and AArch64. Implements a custom lifter that converts machine instructions into a side-effect-aware IR.
* **Optimization Layer:** Leverages LLVM’s optimization passes (SROA, GVN, DCE) to perform "Symbolic Execution-lite," effectively collapsing obfuscated branches and dead-store loops.
* **Back-end:** Can re-emit cleaned binaries or provide a JIT environment for high-speed analysis of unpacked payloads.

### >> Project Transmissions (Dev Logs)
The following logs document the development milestones, research breakthroughs, and technical hurdles encountered during the Revenant lifecycle.

| ID | Case Title | Focus | Status | Date |
| :--- | :--- | :--- | :--- | :--- |
{% assign sorted_logs = site.projects | where: "project", "revenant" | sort: "date" | reverse -%}
{% for log in sorted_logs -%}
  {% if log.url != page.url -%}
| <a href="{{ log.url | relative_url }}">**#{{ forloop.index | prepend: '00' | slice: -3, 3 }}**</a> | <a href="{{ log.url | relative_url }}">**{{ log.title }}**</a> | `{{ log.focus }}` | {{ log.status }} | **{{ log.date | date: "%Y-%m-%d" }}** |
  {% endif -%}
{% endfor %}

### Technical Roadmap
- [ ] Pipeline implementation.
- [ ] Initial trace collector implementation.
- [ ] Initial Pre-Lifter implementation.
- [ ] Initial x86_64 Lifter implementation.
- [ ] Integration of Z3 for automated SMT-based opaque predicate solving.
- [ ] Exporter implementation.
- [ ] Language bindings (Py, JS, Java, C, C++).
