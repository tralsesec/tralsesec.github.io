---
layout: project
title: "BAF – Buffer Overflow Automation Framework"
status: "ARCHIVED"
period: "Jan 2023 – March 2023"
language: "Python"
field: "Exploit Development"
tech: ["Python", "x86", "ROP Chains", "WinDbg", "Fuzzing"]
date: 2023-01-01
github: "https://github.com/tralsesec/BAF"
---

A custom exploitation tool written in Python to automate the detection and exploitation of x86 stack-based buffer overflows. This framework was developed at age 15, establishing my foundation in low-level memory corruption.

### Operational Capabilities

* **Automated Fuzzing:** Scripted a modular fuzzer to identify crash offsets and discover "bad characters" in remote targets automatically.
* **Payload Generation:** Streamlined the construction of ROP (Return Oriented Programming) chains and shellcode injection to bypass non-executable stack protections.
* **Targeted Analysis:** Utilized `WinDbg` and `Mona.py` integration to automate the search for viable "Jump" instructions (e.g., `JMP ESP`) across loaded modules.



### Impact
BAF was a pivot point in my research, moving from manual exploitation to programmatic vulnerability analysis. It successfully automated the "oscp-style" overflow process, reducing a multi-hour manual task to a matter of minutes.
