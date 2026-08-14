---
name: adr
description: >-
  Record and enforce Architecture Decision Records (ADRs) in Markdown under
  ~/mds4xgl3/.adr/. Use when creating or updating an ADR, when the user
  mentions ADR / architecture decision / .adr, or before making architectural
  or cross-module changes that could conflict with prior decisions.
---

# Architecture Decision Records (ADR)

## When to use

- User asks to write, update, or review an ADR.
- Architectural or cross-module changes (new ownership boundaries, protocol
  paths, shared library contracts, migrate-vs-keep-in-place choices).
- A proposed design would supersede or conflict with an existing ADR.

Default location: `~/mds4xgl3/.adr/` (create the directory if missing).
ADRs are **project-wide** for mds4xgl3, not per-package under `buildroot/dl/`.
Do not commit ADRs into individual package repos (e.g. `lib_moxa_ies_auto_mibs`).

## Mandatory rule (before architectural / cross-module changes)

Before making architectural or cross-module changes:

1. Search `~/mds4xgl3/.adr/` for relevant ADRs.
2. Summarize the applicable decisions and constraints.
3. Ensure the proposed change does not silently violate them.
4. If the change supersedes an existing decision, update its status and
   create a new ADR describing the replacement decision.
5. Do not edit historical ADR content merely to make it match the new design.

## ADR file naming

- Filename: `~/mds4xgl3/.adr/ADR-XXXX-<short-kebab-title>.md`
- `XXXX` is a zero-padded sequence (`0001`, `0002`, …). Next number = max
  existing `ADR-XXXX` + 1. If none exist, start at `0001`.

## Status values

Use one of: `Proposed` | `Accepted` | `Deprecated` | `Superseded by ADR-XXXX`

When superseding: set old ADR Status to `Superseded by ADR-XXXX`; new ADR
Status `Accepted` (or `Proposed` if still under review). Do not rewrite the
old ADR's Context / Decision / Alternatives to match the new design.

## Template (required fields — use verbatim structure)

Every ADR MUST include at least these fields, in this order, as Markdown:

```markdown
# ADR-XXXX: 決策標題

Status:
Date:
Context:
Decision:
Alternatives Considered:
Consequences:
Constraints / Assumptions:
Related Files / Modules:
Related ADRs:
```

Fill each field with concrete prose (not empty). Date = ISO `YYYY-MM-DD`.

### Field emphasis (what matters most for AI)

| Field | Purpose |
|-------|---------|
| **Context** | 當時要解決什麼問題。 |
| **Decision** | 最後決定採用什麼方案。 |
| **Alternatives Considered** | 為何不採用其他方案。 |
| **Consequences** | 這個決策帶來哪些成本、限制和後續責任。 |
| **Related Files / Modules** | 讓 AI 能從 ADR 快速定位程式碼（paths, package names）。 |

Also fill Status, Date, Constraints / Assumptions, Related ADRs (or `None`).

## Workflow: create an ADR

1. Confirm the decision is architectural (not a one-line bugfix).
2. List next `ADR-XXXX` from `~/mds4xgl3/.adr/`.
3. Write the file using the template above.
4. Put concrete paths under Related Files / Modules (under `buildroot/dl/...`
   when referring to packages).
5. Link Related ADRs by id (`ADR-0003`) when relevant.
6. Report the file path to the user; do not commit unless asked.
   Never commit ADRs into package git repos unless the user explicitly asks.

## Workflow: supersede an ADR

1. Read the old ADR; leave historical Context/Decision/Alternatives intact.
2. Change only its **Status** line to `Superseded by ADR-XXXX`.
3. Create the new ADR with Status `Accepted` (or `Proposed`) and
   Related ADRs pointing at the old one.
4. Summarize for the user: what changed and why.

## Do not

- Silently violate an Accepted ADR.
- Rewrite old ADR body to “update history.”
- Skip Related Files when the decision touches code.
- Invent ADR numbers that collide with existing files.
- Place ADRs under per-package `docs/adr/` for mds4xgl3 work.
