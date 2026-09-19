---
layout: page
title: Profile
no_toc: true
---

<h1>Systems & Security Engineering</h1>

<div style="border: 1px solid var(--border); padding: 1.5rem; margin-bottom: 2rem; background: #0f0f0f;">
  <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
    <div>
      <span class="fg-dim">ROLE</span><br>
      <span class="text-green">Security Researcher & Systems Engineer</span>
    </div>
    <div>
      {% assign current_year = site.time | date: '%Y' | plus: 0 %}
      {% assign total_exp = current_year | minus: 2017 %}
      <span class="fg-dim">CORE FOCUS</span><br>
      <span>Low-Level Architecture & Offensive Security</span>
    </div>
    <div>
      <span class="fg-dim">LOCATION</span><br>
      <span>Germany (Remote / On-Site by arrangement)</span>
    </div>
    <div>
      <span class="fg-dim">ENGAGEMENT</span><br>
      <span class="text-green">B2B / Freelance & Research</span>
    </div>
  </div>
</div>

<h2>// Technical Profile</h2>

<p>
  Bridging low-level systems engineering with real-world offensive security. My background is rooted in core software engineering since 2017, transitioning into vulnerability research, kernel-level analysis, and telemetry validation.
</p>

<p>
  I develop purpose-built tooling and high-performance software using C, Zig, and Go to evaluate defensive architectures, isolate deep logic flaws, and build resilient network systems.
</p>

<h3 class="text-green">Core Stack & Focus Areas</h3>
<table>
  <thead>
    <tr>
      <th style="width: 30%;">Ecosystem</th>
      <th style="width: 25%;">Active Since</th>
      <th>Applied Engineering / Use Cases</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>C / C++ / x86 asm</strong></td>
      <td><span class="fg-dim">2022 - {{ site.time | date: '%Y' }}</span></td>
      <td>Linux/Windows Internals, Binary Exploitation, Socket Architecture.</td>
    </tr>
    <tr>
      <td><strong>Zig / Rust</strong></td>
      <td><span class="fg-dim">2025 - {{ site.time | date: '%Y' }}</span></td>
      <td>Memory-safe Systems Tooling, Native Performance, Telemetry Research.</td>
    </tr>
    <tr>
      <td><strong>Go (Golang)</strong></td>
      <td><span class="fg-dim">2024 - {{ site.time | date: '%Y' }}</span></td>
      <td>High-Throughput Distributed Backends, Network Daemons, Custom Tooling.</td>
    </tr>
    <tr>
      <td><strong>Python</strong></td>
      <td><span class="fg-dim">2017 - {{ site.time | date: '%Y' }}</span></td>
      <td>Exploit Automation, Protocol Parsing, Rapid Prototyping.</td>
    </tr>
    <tr>
      <td><strong>AppSec & Web Core</strong></td>
      <td><span class="fg-dim">2020 - 2022</span></td>
      <td>API Audits, Source Code Review, Enterprise Identity & Auth Flaws.</td>
    </tr>
  </tbody>
</table>

<hr style="margin: 3rem 0; border-color: var(--border);">

<h2>// Track Record</h2>

<div style="margin-bottom: 2rem;">
  <h3 style="margin-bottom: 0.2rem;"><a href="https://telekom.de/" target="_blank">Deutsche Telekom</a></h3>
  <div class="fg-dim" style="font-family: var(--font-mono); font-size: 0.85rem; margin-bottom: 1rem;">
    <span class="text-green">DevSecOps & Cloud Security</span> // Sept 2025 - Feb 2026
  </div>
  <p>
    Hardened enterprise cloud architectures and automated compliance-critical infrastructure delivery. Focused on secure pipeline integration and network boundary protection.
  </p>
  <div style="font-size: 0.85rem;">
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">Golang</span>
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">Bash</span>
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">Enterprise Cloud</span>
  </div>
</div>

<div style="margin-bottom: 2rem;">
  <h3 style="margin-bottom: 0.2rem;"><a href="https://u-glow.de/" target="_blank">U-Glow</a></h3>
  <div class="fg-dim" style="font-family: var(--font-mono); font-size: 0.85rem; margin-bottom: 1rem;">
    <span class="text-green">Network & Systems Engineer</span> // Sept 2023 - Dec 2023
  </div>
  <p>
    Engineered sensor logic and packet inspection components for critical industrial environments. Implemented robust protocol analysis across low-level network boundaries.
  </p>
  <div style="font-size: 0.85rem;">
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">C++</span>
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">Industrial Protocols</span>
  </div>
</div>

<div style="margin-bottom: 2rem;">
  <h3 style="margin-bottom: 0.2rem;"><a href="https://doctronic.de/" target="_blank">doctronic</a></h3>
  <div class="fg-dim" style="font-family: var(--font-mono); font-size: 0.85rem; margin-bottom: 1rem;">
    <span class="text-green">Software Engineering</span> // July 2023 - Aug 2023
  </div>
  <p>
    Engineered backend systems with strict focus on functional paradigms, deterministic execution, and resilient data processing.
  </p>
  <div style="font-size: 0.85rem;">
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">Clojure</span>
  </div>
</div>

<hr style="margin: 3rem 0; border-color: var(--border);">

<h2>// Research & Certifications</h2>

<div style="display: grid; grid-template-columns: 1fr; gap: 2rem;">
  <div>
    <h3>Offensive Security Benchmarks</h3>
    <p>
      Continuous validation of exploit techniques across complex enterprise environments. Primary focus on Active Directory architecture, binary exploitation, and kernel internals.
    </p>
    <ul style="list-style: none; padding-left: 0; margin-bottom: 2rem;">
      <li>
        <a href="https://app.hackthebox.com/public/users/475600" target="_blank"><span class="text-green">Hack The Box Ranking</span></a> <span class="fg-dim">// Active</span><br>
        Ranked among the top tiers globally and nationally in practical adversary emulation.
      </li>
    </ul>

    <h3>Formal Credentials & Certifications</h3>
    <ul style="margin-bottom: 0; list-style-type: none; padding-left: 0;">
      <li style="margin-bottom: 0.6rem;"><strong>HTB CPTS</strong> : Certified Penetration Testing Specialist <span class="text-green" style="font-family: var(--font-mono); font-size: 0.85rem; font-weight: bold; margin-left: 8px;">[VERIFIED]</span></li>
      <li style="margin-bottom: 0.6rem;"><strong>HTB CAPE</strong> : Certified Active Directory Penetration Expert <span class="text-green" style="font-family: var(--font-mono); font-size: 0.85rem; font-weight: bold; margin-left: 8px;">[VERIFIED]</span></li>
      <li style="margin-bottom: 0.6rem;"><strong>HTB CWEE</strong> : Certified Web Exploitation Expert <span class="text-green" style="font-family: var(--font-mono); font-size: 0.85rem; font-weight: bold; margin-left: 8px;">[VERIFIED]</span></li>
      <li style="margin-bottom: 0.6rem;"><strong>Maldev Academy</strong> : Windows Internals & Evasion Techniques</li>
      <li style="margin-bottom: 0.6rem;"><strong>OffSec OSED</strong> : Windows User Mode Exploit Development</li>
      <li><strong>OffSec OSEE</strong> : Advanced Windows Kernel Exploitation</li>
    </ul>
  </div>
</div>
