---
layout: page
title: "Deadlock Condition via Conflicting Mandates ('Logical Circularity')"
cwe_id: "OIE-102"
category: "Governance Logic"
severity: "High"
status: "Active"
---

# OIE-102: Deadlock Condition via Conflicting Mandates ('Logical Circularity')

## Definition
Two distinct governance policies conflict in such a way that the system enters a deadlock state. To execute Policy A, the operator is mathematically forced to violate Policy B. 

## Forensic Characteristics
* **Trigger:** An operator attempts to complete a standard operational task that falls under overlapping regulatory frameworks (e.g., Data Privacy vs. Immediate Client Support).
* **Failure State:** The system freezes. The operator must either halt production entirely or engage in "Shadow IT" (bypassing official systems) to complete the task, thereby breaking compliance just to keep the business running.

## Remediation
Execute a Dependency Analysis on all mandatory policies. Introduce an "Exception Override" protocol that explicitly defines which mandate takes priority when a deadlock occurs, legally protecting the operator who follows the override.
