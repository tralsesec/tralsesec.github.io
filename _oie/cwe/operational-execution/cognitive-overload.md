---
layout: page
title: "Improper Limitation of Decision Authority ('Cognitive Overload')"
cwe_id: "OIE-202"
category: "Operational Execution"
severity: "High"
status: "Active"
---

# OIE-202: Improper Limitation of Decision Authority ('Cognitive Overload')

## Definition
The concentration of decision-making power into a single node without secondary validation or load balancing. It creates a massive bottleneck and a single point of failure where a corrupted input from that specific node overrides all downstream safety protocols.

## Forensic Characteristics
* **Trigger:** A sudden spike in operational volume or a critical edge-case request.
* **Failure State:** The singular authority node is overwhelmed (Cognitive Overload). To clear the queue, the node begins rubber-stamping approvals or making high-risk decisions without sanitization checks, flooding the downstream organization with toxic execution paths.

## Remediation
Implement Distributed Decision Architecture. No single node should possess unchecked authority over high-volume execution paths. Introduce threshold limits: routine decisions must be automated or distributed laterally, reserving the central node strictly for flagged anomalies.
