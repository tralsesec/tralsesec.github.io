---
layout: page
title: "Improper Alignment of Control Incentives ('Policy Inversion')"
cwe_id: "OIE-101"
category: "Governance Logic"
status: "Active"
---

# OIE-101: Improper Alignment of Control Incentives ('Policy Inversion')

## Definition
A logic flaw where a governance control fundamentally contradicts its intended outcome, actively incentivizing operators to bypass safety mechanisms in order to satisfy compliance metrics. The control layer becomes a liability rather than a safeguard.

## Forensic Characteristics
* **Trigger:** The introduction of rigid, metric-driven compliance policies that do not account for operational realities or edge cases.
* **Failure State:** Operators engage in "malicious compliance." They satisfy the superficial paper requirement of the policy while simultaneously executing undocumented, high-risk workarounds to maintain throughput. The system logs a false positive for security while actual risk grows exponentially.

## Remediation
Deprecate isolated compliance checklists. Refactor the governance layer to measure outcome-based telemetry rather than binary inputs. Redesign the incentive matrix so that the operational path of least resistance inherently aligns with the highest security state of the organization.
