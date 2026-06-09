---
layout: page
title: Organizational Pentesting (OPT)
permalink: /oie/opt/
---

## Overview
Organizational Pentesting (OPT) is the active, tactical execution phase of <a href="/oie/ait/">Adversarial Integrity Testing (AIT)</a>. While AIT provides the formal scientific protocol, OPT provides the offensive methodologies required to validate the structural integrity of an institution. It represents the direct weaponization of adversarial pressure against the governance, operational, and decision-making layers of an organization.

## Core Objective
The objective of OPT is to actively exploit architectural logic bugs before they cause unmitigated systemic failure. While traditional audits verify the static existence of policy documentation, OPT forces the system into a high-pressure execution state to verify the functional reality of those controls.

## Adversarial TTP Matrix (Tactics, Techniques, & Procedures)
OPT engagements utilize a standardized playbook of adversarial maneuvers engineered to force an organization to expose specific **OIE-CWE** vulnerabilities. 

To maintain operational consistency with traditional cybersecurity methodologies, the OPT playbook mirrors the established structure of the MITRE ATT&CK framework, translating digital exploits into organizational logic vectors. 

### The Organizational Kill Chain
* **Reconnaissance & Resource Development:** Mapping the organizational chart, identifying SLA timelines, and drafting highly specific legal or regulatory triggers designed to force a system response.
* **Initial Access & Execution:** Injecting the trigger into a targeted administrative node (like a support desk or compliance inbox) to initiate unmonitored internal workflows.
* **Persistence & Privilege Escalation:** Engineering the interaction so lower level administrative nodes cannot safely close the ticket, forcing them to escalate the logic bomb up the management chain.
* **Defense Impairment & Stealth:** Bypassing automated HR filters or legal auto responders to ensure the trigger reaches a human decision maker who is forced into a state of cognitive overload.
* **Lateral Movement & Collection:** Forcing isolated departments (e.g., IT and Legal) into conflicting mandates, then capturing their asynchronous email timestamps, physical signatures, and contradictory system states.
* **Impact:** Forcing the ultimate logic collapse, executing the cover up, and scientifically verifying the resulting CWE.

## Active TTP Matrix

Below is the active registry of all standardized OPT techniques used to stress test organizational systems, categorized by their primary tactic.

<table class="ttp-matrix">
  <thead>
    <tr>
      <th>ID</th>
      <th>Title</th>
      <th>Status</th>
    </tr>
  </thead>
  <tbody>
    {% assign ttp_files = site.oie | where_exp: "item", "item.path contains '_oie/opt/ttp/'" %}
    {% assign sorted_map = "" | split: "" %}

    {% for item in ttp_files %}
      {% assign folder_parts = item.path | split: '/' %}
      {% assign folder_name = folder_parts[3] %}
      {% assign folder_num = folder_name | split: '-' | first | plus: 0 %}

      {% comment %} 1. Pad number to 2 digits (e.g. 1 -> 01) {% endcomment %}
      {% capture padded_num %}{% if folder_num < 10 %}0{{ folder_num }}{% else %}{{ folder_num }}{% endif %}{% endcapture %}

      {% comment %} 
         2. Create sort key: '01.0' for index, '01.1' for technique.
         String sorting will now handle 01, 02... 10 perfectly.
      {% endcomment %}
      {% if item.ttp_id == nil %}
        {% assign sort_key = padded_num | append: ".0" %}
      {% else %}
        {% assign sort_key = padded_num | append: ".1" %}
      {% endif %}

      {% capture combined %}{{ sort_key }}::{{ item.path }}{% endcapture %}
      {% assign sorted_map = sorted_map | push: combined %}
    {% endfor %}

    {% comment %} 3. Sort alphanumeric (01.0 < 01.1 < 02.0 ...) {% endcomment %}
    {% assign sorted_map = sorted_map | sort %}

    {% for entry in sorted_map %}
      {% assign path = entry | split: "::" | last %}
      {% assign item = site.oie | where: "path", path | first %}
      {% assign folder_parts = item.path | split: '/' %}
      {% assign folder_num = folder_parts[3] | split: '-' | first | plus: 0 %}

      <tr>
        <td>
          <strong>
            {% if item.ttp_id %}
              {{ item.ttp_id }}
            {% else %}
              <span class="text-green">T{{ folder_num }}-000</span>
            {% endif %}
          </strong>
        </td>
        <td>
          <a href="{{ item.url | relative_url }}">
            {% if item.ttp_id %}
              {{ item.title }}
            {% else %}
              <em>{{ item.title }}</em>
            {% endif %}
          </a>
        </td>
        <td>{{ item.status | default: "Active" }}</td>
      </tr>
    {% endfor %}
  </tbody>
</table>

## Distinction from Auditing
Traditional audits rely on static checklist verification and internal self-reporting. OPT relies on empirical execution. It does not ask if a policy exists; it tests whether the system possesses the structural capacity to execute that policy under conditions of stress, confusion, or active adversarial manipulation.
