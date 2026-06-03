---
layout: page
title: Profile
no_toc: true
---

<h1>The Architect & Operator</h1>

<div style="border: 1px solid var(--border); padding: 1.5rem; margin-bottom: 2rem; background: #0f0f0f;">
  <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
    <div>
      <span class="fg-dim">CURRENT STATUS</span><br>
      <span class="text-green">Independent Vulnerability Researcher</span>
    </div>
    <div>
      {% assign current_year = site.time | date: '%Y' | plus: 0 %}
      {% assign total_exp = current_year | minus: 2017 %}
      <span class="fg-dim">ENGINEERING EXP</span><br>
      <span>{{ total_exp }} Years (Low-Level & Architecture)</span>
    </div>
    <div>
      {% assign total_sec = current_year | minus: 2020 %}
      <span class="fg-dim">SEC OPS</span><br>
      <span>{{ total_sec }} Years (Adversary Simulation)</span>
    </div>
    <div>
      <span class="fg-dim">BASE OF OPERATIONS</span><br>
      <span>Germany</span>
    </div>
  </div>
</div>

<h2>// Operational Profile</h2>

<p>
  My methodology is grounded in a software engineering background established in 2017. Current operations focus on deep-level architectural analysis, reverse engineering, and bypassing endpoint telemetry.
</p>

<p>
  I build the weaponry I use, leveraging languages like Python, Zig and Go to maintain absolute operational superiority in zero-day research and adversary simulation.
</p>

<h3 class="text-green">Technical Arsenal</h3>
<table>
  <thead>
    <tr>
      <th style="width: 30%;">Language</th>
      <th style="width: 25%;">Timeframe</th>
      <th>Context / Use Case</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>C / C++ / x86 asm</strong></td>
      <td><span class="fg-dim">2022—{{ site.time | date: '%Y' }}</span></td>
      <td>Ring 0 Operations, Windows Internals, Malware Dev.</td>
    </tr>
    <tr>
      <td><strong>Zig / Nim / Rust</strong></td>
      <td><span class="fg-dim">2025—{{ site.time | date: '%Y' }}</span></td>
      <td>Memory-safe Custom Weaponry, EDR Evasion, Next-Gen C2.</td>
    </tr>
    <tr>
      <td><strong>Go (Golang)</strong></td>
      <td><span class="fg-dim">2024—{{ site.time | date: '%Y' }}</span></td>
      <td>High-Performance Cloud Infra & Distributed Tooling.</td>
    </tr>
    <tr>
      <td><strong>Python</strong></td>
      <td><span class="fg-dim">2017—{{ site.time | date: '%Y' }}</span></td>
      <td>Rapid Prototyping, Exploit Development, Automation.</td>
    </tr>
    <tr>
      <td><strong>JavaScript / Java / Kotlin</strong></td>
      <td><span class="fg-dim">2020-2022</span></td>
      <td>Web Exploitation, Source Code Review, Android.</td>
    </tr>
  </tbody>
</table>

<hr style="margin: 3rem 0; border-color: var(--border);">

<h2>// Deployment History</h2>

<div style="margin-bottom: 2rem;">
  <h3 style="margin-bottom: 0.2rem;"><a href="https://telekom.de/" target="_blank">Deutsche Telekom</a></h3>
  <div class="fg-dim" style="font-family: var(--font-mono); font-size: 0.85rem; margin-bottom: 1rem;">
    <span class="text-green">DevSecOps Engineer</span> // Sept 2025 – Feb 2026
  </div>
  <p>
    Secured enterprise cloud environments and automated infrastructure delivery. Analyzed and hardened high-compliance pipelines before pivoting to independent research.
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
    <span class="text-green">IDS Architect & Engineer</span> // Sept 2023 – Dec 2023
  </div>
  <p>
    Designed and implemented Intrusion Detection Systems (IDS) for critical industrial environments. Worked directly with Programmable Logic Controllers (PLCs) and low-level network security protocols.
  </p>
  <div style="font-size: 0.85rem;">
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">C++</span>
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">PLC/SCADA</span>
  </div>
</div>

<div style="margin-bottom: 2rem;">
  <h3 style="margin-bottom: 0.2rem;"><a href="https://www.doctronic.de/" target="_blank">doctronic GmbH & Co. KG</a></h3>
  <div class="fg-dim" style="font-family: var(--font-mono); font-size: 0.85rem; margin-bottom: 1rem;">
    <span class="text-green">Software Engineering</span> // July 2023 – Aug 2023
  </div>
  <p>
    Backend architecture with a strict focus on functional programming paradigms and resilient system design.
  </p>
  <div style="font-size: 0.85rem;">
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">Clojure</span>
  </div>
</div>

<hr style="margin: 3rem 0; border-color: var(--border);">

<h2>// Research & Methodology</h2>

<div style="display: grid; grid-template-columns: 1fr; gap: 2rem;">

  <div>
    <h3>Offensive Research</h3>
    <p>
      Continuous validation of offensive methodologies across diverse environments. My research focuses on the intersection of Windows Internals, Unix/Linux subsystems, and complex network architectures. 
    </p>
    <ul style="list-style: none; padding-left: 0; margin-bottom: 2rem;">
      <li>
        <a href="https://app.hackthebox.com/public/users/475600" target="_blank"><span class="text-green">Hack The Box</span></a> <span class="fg-dim">// 2020—Present</span><br>
        Global top-tier rankings. Primary focus on Binary Analysis, Advanced AD Pivoting, and hardened Linux/Windows environments.
      </li>
    </ul>

    <h3>Specialized Training & Milestones</h3>
    <p>
      A selection of industry-standard benchmarks and specialized training programs used to formalize my research in vulnerability discovery and exploitation.
    </p>
    <ul style="margin-bottom: 0; list-style-type: none; padding-left: 0;">
      <li style="margin-bottom: 0.6rem;"><strong>HTB CPTS</strong> — Penetration Testing Specialist <span class="text-green" style="font-family: var(--font-mono); font-size: 0.85rem; font-weight: bold; margin-left: 8px;">[CERTIFIED]</span></li>
      <li style="margin-bottom: 0.6rem;"><strong>HTB CAPE</strong> — Active Directory Penetration Exploitation</li>
      <li style="margin-bottom: 0.6rem;"><strong>HTB CWEE</strong> — Web Exploitation Expert</li>
      <li style="margin-bottom: 0.6rem;"><strong>Maldev Academy</strong> — Advanced Malware Development</li>
      <li style="margin-bottom: 0.6rem;"><strong>OffSec OSED</strong> — Windows User Mode Exploit Development</li>
      <li><strong>OffSec OSEE</strong> — Windows Kernel Exploitation</li>
    </ul>
  </div>

</div>
