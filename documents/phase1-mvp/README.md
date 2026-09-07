# BakiBondhu — Application Specification (MVP / v1)

> **বাকিবন্ধু** — a Bangla-first, offline-first mobile app that helps Bangladeshi
> micro-merchants get their credit (**বাকি**) paid back — not just written down.

This folder is the **single source of truth for what v1 does**. It turns the MVP
section of the Founder's Kit into a buildable specification: functional
requirements, screens, data model, and acceptance criteria a solo developer can
implement against.

**The golden rule of v1:** if a feature is not written here, it does not exist
until real users beg for it. Scope is the only enemy right now.

---

## How to read these docs

Read them in order the first time; after that, each is a standalone reference.

| # | Document | What it covers |
|---|----------|----------------|
| 00 | [Overview](00-overview.md) | Vision, problem, goals, personas, glossary |
| 01 | [Scope & MVP fence](01-scope-and-mvp.md) | What's in v1, what's explicitly out, assumptions, constraints |
| 02 | [Functional specification](02-functional-spec.md) | The core loop and every functional requirement (`FR-*`) |
| 03 | [Screens](03-screens.md) | The five screens + first-run, field by field |
| 04 | [Data model](04-data-model.md) | Entities, fields, computed balances, integrity rules |
| 05 | [Reminders](05-reminders.md) | The one real differentiator, specced in detail |
| 06 | [Non-functional requirements](06-non-functional.md) | Offline, performance, localization, accessibility, privacy |
| 07 | [Architecture & tech stack](07-architecture.md) | Framework, storage, sync roadmap |
| 08 | [Acceptance criteria](08-acceptance-criteria.md) | Definition of done + a release test checklist |
| 09 | [Roadmap](09-roadmap.md) | Build sequence for v1 and what comes after |

## Requirement IDs

Requirements are tagged so they can be traced from spec → code → test:

- `FR-n` — functional requirement
- `NFR-n` — non-functional requirement
- `DM-n` — data-model rule
- `AC-n` — acceptance criterion

## Status

Pre-launch, plan-ready. This spec describes v1 only. It assumes Phase 0
merchant interviews either confirm the collection pain or reshape the vertical
**before** any of this is built. See the Founder's Kit for the surrounding
strategy, competitor analysis, and financial model.

_Prepared for Rafiq · 2026 · v1_
