---
layout: page
title: "O-SS: Organizational Severity Score"
---

## Overview
The Organizational Severity Score (O-SS) is the deterministic metric used to quantify the risk of architectural logic bugs. Not all organizational failures carry the same weight. To prioritize remediation and maintain empirical rigor, we calculate severity based on three distinct vectors: Impact, Trigger Friction, and Entrenchment.

This acts as the standardized vulnerability scoring system for all entries logged in the [OIE-CWE Database](/oie/cwe/).

## The Vectors

### 1. Impact (I)
This measures the blast radius when the logic bug is triggered. 
* **1 to 3 (Low):** Localized failure. Minor delays, no systemic damage.
* **4 to 6 (Moderate):** Department level disruption. Measurable friction or audit failure.
* **7 to 9 (High):** Systemic collapse. Massive financial or reputational damage.
* **10 (Critical):** Existential threat. Survival or legal standing of the organization is compromised.

### 2. Trigger Friction (T)
This measures how easily the bug is triggered by external pressure or daily operations.
* **1 to 3 (Low):** Requires a highly specific, rare external crisis.
* **4 to 6 (Moderate):** Triggered by routine adversarial probing or aggressive audits.
* **7 to 9 (High):** Triggered constantly by daily operational reality or common human errors.
* **10 (Critical):** Autonomously triggered. Operating normally guarantees the failure.

### 3. Entrenchment (R)
This measures remediation complexity. How deeply embedded is the flaw in the organizational architecture?
* **1 to 3 (Low):** Quick patch. Can be fixed by rewriting a single policy document.
* **4 to 6 (Moderate):** Requires cross departmental coordination to resolve.
* **7 to 9 (High):** Requires changing incentive structures or replacing leadership nodes.
* **10 (Critical):** The bug is the business model. Remediation requires destroying current operational revenue.

---

## The Formula

Impact and Trigger Friction represent the active, immediate threat and carry the highest weight. Entrenchment acts as a secondary modifier because it dictates how long the organization will remain exposed while attempting a fix.

**S = (I * 0.4) + (T * 0.4) + (R * 0.2)**

### Output Scale

| Score Range | Classification | Action Required |
| :--- | :--- | :--- |
| **0.1 to 3.9** | Low | Document and monitor. |
| **4.0 to 6.9** | Moderate | Schedule structural review. |
| **7.0 to 8.9** | High | Immediate architectural intervention. |
| **9.0 to 10.0** | Critical | Halt affected operations. |

---

## Practical Examples

### Case 1: The "Black Swan" Bug (High Impact, Low Trigger)
A massive flaw in the disaster recovery protocol means the company will lose all data if two geographically separated data centers lose power simultaneously.
* **Impact (10):** Total existential collapse.
* **Trigger Friction (2):** Exceptionally rare to trigger.
* **Entrenchment (8):** Requires a massive, expensive architectural rebuild.
* **Calculation:** (10 * 0.4) + (2 * 0.4) + (8 * 0.2)
* **Final O-SS:** 6.4 (Moderate)

### Case 2: The "Papercut" Bug (Low Impact, High Trigger)
An automated onboarding process crashes every time a new employee has a hyphen in their last name, forcing an admin to manually approve the account.
* **Impact (2):** Minor administrative annoyance.
* **Trigger Friction (9):** Happens constantly without adversarial effort.
* **Entrenchment (2):** Takes ten minutes to update a configuration file.
* **Calculation:** (2 * 0.4) + (9 * 0.4) + (2 * 0.2)
* **Final O-SS:** 4.8 (Moderate)

### Case 3: The "Bleeding Neck" Bug (High Impact, High Trigger)
Customer support agents receive financial bonuses for closing tickets quickly. To hit targets, they routinely grant unauthorized refunds without validating complaints.
* **Impact (8):** Massive financial drain and a highly exploitable fraud vector.
* **Trigger Friction (9):** Triggered daily by normal operations.
* **Entrenchment (7):** Requires destroying the KPI model and retraining the department.
* **Calculation:** (8 * 0.4) + (9 * 0.4) + (7 * 0.2)
* **Final O-SS:** 8.2 (High)

