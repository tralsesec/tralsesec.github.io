---
layout: page
title: Profile
---

<h1>The Operator & Researcher</h1>

<div style="border: 1px solid var(--border); padding: 1.5rem; margin-bottom: 2rem; background: #0f0f0f;">
  <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
    <div>
      <span class="fg-dim">ROLE</span><br>
      <span class="text-green">DevSecOps Engineer</span>
    </div>
    <div>
      {% assign current_year = site.time | date: '%Y' | plus: 0 %}
      {% assign total_exp = current_year | minus: 2017 %}
      <span class="fg-dim">TOTAL EXP</span><br>
      <span>{{ total_exp }} Years (Engineering)</span>
    </div>
    <div>
      {% assign total_sec = current_year | minus: 2020 %}
      <span class="fg-dim">SEC OPS</span><br>
      <span>{{ total_sec }} Years (CTF/Red Team)</span>
    </div>
    <div>
      <span class="fg-dim">LOCATION</span><br>
      <span>Germany</span>
    </div>
  </div>
</div>

<h2>// Operational Profile</h2>

<p>
  I am a <strong>DevSecOps Engineer</strong> and Dual Student at <strong>Deutsche Telekom</strong>.
</p>

<p>
  My foundation in software engineering began <strong>2017</strong>, long before I entered the professional sector. This decade-long fluency in code allows me to deconstruct systems with the mindset of an architect, not just a script-kiddie. 
</p>

<p>
  My work operates at the intersection of robust software engineering (Cloud, Go, C++) and applied vulnerability research. I do not just find vulnerabilities; I understand the code that caused them.
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
      <td><strong>Python</strong></td>
      <td><span class="fg-dim">2017—{{ site.time | date: '%Y' }}</span></td>
      <td>The foundation. Automation, POCs, Tooling.</td>
    </tr>
    <tr>
      <td><strong>JavaScript / Java / Kotlin</strong></td>
      <td><span class="fg-dim">2020-2022</span></td>
      <td>Web Exploitation, Code Review, Android (Kotlin).</td>
    </tr>
    <tr>
      <td><strong>C / C++ / x86 asm</strong></td>
      <td><span class="fg-dim">2022—{{ site.time | date: '%Y' }}</span></td>
      <td>Low-Level Systems, Malware Dev, PLC/SCADA.</td>
    </tr>
    <tr>
      <td><strong>Clojure</strong></td>
      <td><span class="fg-dim">2023</span></td>
      <td>Functional Programming paradigms.</td>
    </tr>
    <tr>
      <td><strong>Go (Golang)</strong></td>
      <td><span class="fg-dim">2024—{{ site.time | date: '%Y' }}</span></td>
      <td>High-Performance Cloud Infra & Modern C2.</td>
    </tr>
    <tr>
      <td><strong>Zig / Nim / Rust</strong></td>
      <td><span class="fg-dim">2025—{{ site.time | date: '%Y' }}</span></td>
      <td>Next-Gen Offensive Engineering & Evasion.</td>
    </tr>
  </tbody>
</table>

<hr style="margin: 3rem 0; border-color: var(--border);">

<h2>// Deployment History</h2>

<div style="margin-bottom: 2rem;">
  <h3 style="margin-bottom: 0.2rem;"><a href="https://telekom.de/" target="_blank">Deutsche Telekom</a></h3>
  <div class="fg-dim" style="font-family: var(--font-mono); font-size: 0.85rem; margin-bottom: 1rem;">
    <span class="text-green">DevSecOps Engineer (Dual Study)</span> // Sept 2025 – Present
  </div>
  <p>
    Focusing on Cloud Security, infrastructure automation, and secure software delivery in a high-compliance enterprise environment.
  </p>
  <div style="font-size: 0.85rem;">
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">Golang</span>
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">Bash</span>
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">Cloud</span>
  </div>
</div>

<div style="margin-bottom: 2rem;">
  <h3 style="margin-bottom: 0.2rem;"><a href="https://u-glow.de/" target="_blank">U-Glow</a></h3>
  <div class="fg-dim" style="font-family: var(--font-mono); font-size: 0.85rem; margin-bottom: 1rem;">
    <span class="text-green">IDS Architect & Engineer</span> // Sept 2023 – Dec 2023
  </div>
  <p>
    Designed and implemented Intrusion Detection Systems (IDS) for industrial environments. Worked directly with Programmable Logic Controllers (PLCs) and network security protocols.
  </p>
  <div style="font-size: 0.85rem;">
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">C++</span>
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">PLC/SCADA</span>
  </div>
</div>

<div style="margin-bottom: 2rem;">
  <h3 style="margin-bottom: 0.2rem;"><a href="https://www.doctronic.de/" target="_blank">doctronic GmbH & Co. KG</a></h3>
  <div class="fg-dim" style="font-family: var(--font-mono); font-size: 0.85rem; margin-bottom: 1rem;">
    <span class="text-green">Software Development Internship</span> // July 2023 – Aug 2023
  </div>
  <p>
    Backend development with a focus on functional programming paradigms.
  </p>
  <div style="font-size: 0.85rem;">
    <span style="border: 1px solid #333; padding: 2px 6px; border-radius: 4px; margin-right: 5px;">Clojure</span>
  </div>
</div>

<hr style="margin: 3rem 0; border-color: var(--border);">

<h2>// Active Operations</h2>

<div style="display: grid; grid-template-columns: 1fr; gap: 2rem;">

  <div>
    <h3>Offensive Security</h3>
    <p>
      I have been competing since 2020, focusing on Active Directory exploitation, Red Teaming, and Binary Exploitation.
    </p>
    <ul style="list-style: none; padding-left: 0;">
      <li style="margin-bottom: 0.5rem;">
        <a href="https://app.hackthebox.com/public/users/475600" target="_blank"><span class="text-green">Hack The Box</span></a> <span class="fg-dim">// Since Dec 2020</span><br>
        Top ranks in Reverse Engineering & AD Pivoting.
      </li>
      <li style="margin-bottom: 0.5rem;">
        <a href="https://tryhackme.com/p/Tralse" target="_blank"><span class="text-green">TryHackMe</span></a> <span class="fg-dim">// Since March 2021</span><br>
        Focus on Network Penetration Testing.
      </li>
    </ul>

    <h3>Strategic Roadmap</h3>
    <p>
      Current training objectives to support my role at Telekom and personal research.
    </p>
    <ul>
      <li><span class="text-green"><strong>Active:</strong></span> <strong>HTB CPTS</strong> (Certified Penetration Testing Specialist).</li>
      <li><span class="fg-dim">Target:</span> <strong>HTB CAPE</strong> (Certified Active Directory Penetration Exploitation).</li>
      <li><span class="fg-dim">Target:</span> <strong>HTB CWEE</strong> (Certified Web Exploitation Expert).</li>
      <li><span class="fg-dim">Target:</span> <strong>Maldev Academy</strong> (Certified Advanced Malware Developer).</li>
      <li><span class="fg-dim">Target:</span> <strong>OffSec OSEP</strong> (OffSec Experienced Penetration Tester).</li>
      <li><span class="fg-dim">Target:</span> <strong>OffSec OSED</strong> (OffSec Exploitation Developer).</li>
      <li><span class="fg-dim">Target:</span> <strong>OffSec OSEE</strong> (OffSec Exploitation Expert).</li>
    </ul>
  </div>

</div>

<p style="text-align: center; font-family: var(--font-mono); opacity: 0.5;">
  // END OF RECORD
</p>
