---
layout: page
title: "OIE-CWE: Common Weakness Enumeration"
permalink: /oie/cwe/
---

## OIE-CWE: Common Weakness Enumeration

This database serves as the official registry of structural logic flaws identified through the protocol defined in `ait.md`. Each entry represents a verified vulnerability in organizational decision making logic.

| ID | Title | Category | Status |
| :--- | :--- | :--- | :--- |
{% assign sorted_bugs = site.oie | where_exp: "item", "item.cwe_id != nil" | sort: 'cwe_id' -%}
{% for bug in sorted_bugs -%}
| **{{ bug.cwe_id }}** | <a href="{{ bug.url | relative_url }}">**{{ bug.title }}**</a> | {{ bug.category }} | {{ bug.status }} |
{% endfor %}

---

## Methodology Reference
* **Scoring Protocol:** To understand the math behind the vulnerability severity, review the <a href="{{ '../oss' }}">Organizational Severity Score (O-SS)</a>.
* **Discovery Protocol:** To understand how these vulnerabilities are discovered and mapped, refer to the <a href="{{ '../ait' }}">AIT Framework</a>.
