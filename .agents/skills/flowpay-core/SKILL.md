---
name: flowpay-core
description: >-
  Single source of truth and persistent memory for the hackathon project.
  Consult this skill on every turn to understand what the app is about,
  what has already been built, and what needs to be done next.
---

# Project Memory & Runbook

This document serves as the living source of truth for the project throughout the hackathon. It guarantees zero context loss between sessions and ensures seamless collaboration across all developers and AI assistants.

---

## 📌 1. What the App is About

* **Project Name**: FlowPay
* **Problem**: *(To be populated upon your initial product prompt)*
* **Target Audience**: *(To be populated upon your initial product prompt)*
* **Core Value Proposition**: *(To be populated upon your initial product prompt)*
* **Key User Journeys**: *(To be populated upon your initial product prompt)*

---

## 🏗️ 2. Technical Architecture & Stack

| Layer | Technology | Status / Notes |
| :--- | :--- | :--- |
| **Frontend** | TBD | Pending initial prompt |
| **Backend / Services** | TBD | Pending initial prompt |
| **Data / Storage** | TBD | Pending initial prompt |
| **External Integrations** | TBD | Pending initial prompt |

---

## ✅ 3. What Has Been Done

* [x] **Project Inception & Memory Framework Setup**:
  * Workspace initialized with git.
  * Established project guidelines and AI agent persistence rules in [AGENTS.md](file:///AGENTS.md).
  * Created master project memory skill in [flowpay-core SKILL.md](file:///.agents/skills/flowpay-core/SKILL.md).
  * Created module skill template in [MODULE_SKILL_TEMPLATE.md](file:///.agents/skills/templates/MODULE_SKILL_TEMPLATE.md).

---

## 🎯 4. What Needs to Be Done

### Immediate Next Steps
- [ ] Awaiting user product and architecture specification prompt.
- [ ] Initialize project runtime and dependencies based on stack requirements.
- [ ] Populate "What the App is About" and "Technical Architecture" with app-specific details.
- [ ] Implement core features and modules with dedicated subsystem skills.

---

## 📂 5. Project Directory Structure

```text
flowpay/
├── AGENTS.md                                # Mandatory rules and developer collaboration protocol
└── .agents/
    └── skills/
        ├── flowpay-core/
        │   └── SKILL.md                     # Master project memory (this file)
        └── templates/
            └── MODULE_SKILL_TEMPLATE.md     # Template for subsystem skills
```

---

## 👥 6. Developer Runbook

* **Before any task**: Review this skill file to align on current state and immediate priorities.
* **During task**: Write modular, typed code with zero undocumented assumptions.
* **After any task**: Update this file (mark completed items, add newly created files, revise roadmap).
