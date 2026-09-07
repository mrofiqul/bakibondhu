# BakiBondhu — Web App

The **management, reporting, monitoring and administration** interface (React + TypeScript).
Online-first; always talks to the shared backend API and shares all business rules with the
Android app through it (app-spec §29).

## Governing specifications

| Concern | Document |
|---|---|
| Screens, tables, filters, role-gating | `../documents/BakiBondhu_Web_UIUX_Specification` |
| Product/functional requirements | `../documents/BakiBondhu_Android_Web_Application_Specification_v1.1` |
| API contract | `../documents/BakiBondhu_REST_API_Specification` |
| Data model & reports source | `../documents/BakiBondhu_Database_Specification` |
| Structure, style, testing | `../documents/BakiBondhu_Development_Coding_Standards` |

## Folder structure (Coding Standards §2.3)

```
src/
  components/   reusable UI (tables, KPI tiles, charts, form fields, status pills)
  pages/        routed screens (dashboard, customers, receivables, reports, settings…)
  features/     feature modules (customers, collections, promises, reports, users…)
  services/     typed API layer (one client per resource; server-side paging/filter/sort)
  hooks/        data-fetching & UI hooks
  types/        shared TypeScript types (mirror API DTOs)
  utils/        formatting (৳ lakh grouping, Asia/Dhaka dates, money-as-string)
  auth/         JWT handling, role-based route/control gating (§6)
```

## Getting started

1. Scaffold with Vite + React + TypeScript (`strict: true`) in this folder.
2. Add: a router, a data-fetching library, a table/chart library, and a component system.
3. Build **auth + dashboard + customers** first, then receivables/collections, then reports.

**Non-negotiables:** every list paginates/filters/sorts **server-side**; role gating matches
the Web UI/UX §5 matrix on **both** UI and API; money is rendered from fixed-decimal strings
(never parsed as float); a web user can never see another business's data.
