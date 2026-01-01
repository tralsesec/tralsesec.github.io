---
layout: ctf
title: "HackTheBox: Eloquia"
platform: "HackTheBox"
type: "Machine"
difficulty: "Insane"
image: "/assets/img/ctf/eloquia.png"
tags: [Windows, Backup, VHD, ShadowCopy]
date: 2025-12-30
---

**Mission Brief:** Eloquia is an easy-rated Windows machine involving the mounting of a remote VHD backup to extract SAM and SYSTEM hives for credential dumping.

### Enumeration
We start with a standard `nmap` scan:
```bash
nmap -sC -sV -oA nmap/eloquia 10.10.10.134

<SNIP>
```
