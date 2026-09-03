# AI Assistants & Developer Protocol

Welcome to the repository. This project is built collaboratively by developers and AI agents for a hackathon.

To ensure continuous alignment, eliminate context loss across sessions and developers, and maintain a single source of truth, all contributors (human and AI) must follow the directives below.

---

## 🧠 Core Directives for AI Assistants

### 1. Mandatory Context Loading
Before writing any code, planning changes, or executing commands:
- Inspect `.agents/skills/` (starting with [flowpay-core](file:///.agents/skills/flowpay-core/SKILL.md)).
- Read and adhere to the 3 foundational questions:
  1. **What is the app about?** (Vision, core problem, user personas, architecture).
  2. **What has been done?** (Existing modules, components, APIs, schema, tests).
  3. **What needs to be done?** (Prioritized roadmap, pending tasks, immediate next steps).

### 2. Mandatory Skill Updates on Every Build
Whenever you create, refactor, or complete any feature, component, API, or system:
- **Update the Master Skill ([flowpay-core](file:///.agents/skills/flowpay-core/SKILL.md))**:
  - Keep **"What Has Been Done"** strictly up-to-date with completed deliverables.
  - Update **"What Needs To Be Done"** by checking off completed items and refining the backlog.
  - Update any architectural or stack adjustments.
- **Create Subsystem Skills for Substantial Modules**:
  - Whenever a major subsystem is introduced (e.g., frontend, smart contracts, backend/indexer, payment engine), create `.agents/skills/<module-name>/SKILL.md` using the template at [MODULE_SKILL_TEMPLATE.md](file:///.agents/skills/templates/MODULE_SKILL_TEMPLATE.md).

### 3. Official BMONI Documentation & API Key Protocol
- **Single Source of Truth**: Always consult the official BMONI documentation at [bkey.mintlify.app](https://bkey.mintlify.app/) and its machine-readable index at [bkey.mintlify.app/llms.txt](https://bkey.mintlify.app/llms.txt) prior to implementing any BMONI feature, endpoint, or SDK integration.
- **Explicit API Key Requests**: Never invent fake API keys or hardcode placeholder secrets for BMONI production/sandbox environments. Whenever an implementation requires an API key, webhook secret, or partner credential, explicitly ask the user for it.

---

## 👥 Multi-Developer Team Standards

1. **Self-Documenting Code & Architecture**:
   - Write clean, modular, typed code.
   - Provide explicit environment setup and runnable verification commands.
2. **Zero Hidden Assumptions**:
   - Every external dependency, API, or mock must be documented in the corresponding skill file.
3. **Continuous Alignment**:
   - Always check the latest status in `.agents/skills/` before starting work to avoid duplicate effort.
