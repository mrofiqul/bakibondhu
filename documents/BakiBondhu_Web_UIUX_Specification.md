# BakiBondhu — Web UI/UX Specification

**Version 1.0** · Companion to the Application Specification (v1.1)
Platform: React + TypeScript · Role: management, reporting, monitoring, administration

---

## 1. Purpose & scope

Specifies every web screen for the management/back-office application (app-spec §11–14).
The web app is the **management, reporting, monitoring and administration** interface
(§29); it is online-first and always talks to the backend API. It shares all business
rules with Android through that backend. This document covers layout, screens, states,
tables, filters, and role-gated visibility.

## 2. Design principles (Web)

- **Scan and operate, not read.** Information-dense dashboard and tables; summary before
  detail; state encoded as pills/stripes so what needs attention reads at a glance.
- **Role-aware (§6).** Every screen and action is gated by the signed-in user's role.
- **Bangla-first with English option (§33).** UI in Bangla; English toggle. Money in ৳,
  lakh grouping; dates in Asia/Dhaka.
- **Server-driven data (§21/§23).** All lists paginate, filter and sort server-side.
- **Consistent tables.** Same column grammar everywhere: entity · money (right-aligned,
  tabular) · status pill · actions.

## 3. Layout & shell

- **Left nav:** Dashboard · Customers · Receivables · Collections · Promise-to-Pay ·
  Sales Reps · Assignments · Reports · Reminders · Users & Roles · Subscription ·
  Settings · Audit Log.
- **Top bar:** business switcher (multi-business), global search, user menu, language toggle.
- **Content:** breadcrumb + page title + primary actions (role-gated).
- **Responsive:** usable from 1024px up; tables scroll horizontally within their own container.

## 4. Screen specifications

### 4.1 Login & Authentication (§8.1)
Password and phone+OTP; forgot-password; session via JWT (access + refresh). Rate-limited.

### 4.2 Business Dashboard (§12)
- **KPI tiles:** Total Credit Sales · Total Receivable · Collected This Month · Overdue
  Amount · Customers with Outstanding · Collection Rate.
- **Panels:** Top Outstanding Customers · Top Collection Priorities · Broken Promises ·
  Recent Transactions.
- **Charts (§14):** Receivable Aging · Credit vs Collection · Outstanding Trend · Top 10
  Outstanding · Collection Performance · Promise-to-Pay vs Actual. Charts read the theme,
  label real values, and cite the same figures as the tiles.

### 4.3 Customer Management (§8.3–8.5)
- **List:** search, filters (Outstanding/Paid/Overdue/Due Today, area, sales rep), sort;
  columns: Customer · Balance · Overdue · Overdue days · Sales rep · Status · Actions.
- **Detail:** profile, rollups (balance, total credit/paid, overdue, oldest due),
  transaction/collection/promise history, consent flags. Edit and deactivate (never delete).

### 4.4 Receivables (§10)
- **Summary:** business totals. **Aging report:** buckets 0–7/8–30/31–60/61–90/90+ per
  customer (from the corrected aging model — ages *unpaid* credit). **Priorities:**
  collection-priority-ranked list with score, overdue days, broken promises.

### 4.5 Collections (§8.8)
- Activity feed and per-customer history; create/update activity; filter by status,
  method, follow-up date, sales rep. "Requires follow-up" and "broken promise" queues.

### 4.6 Promise-to-Pay (§8.9)
- List and detail; status transitions (Open/Fulfilled/Partial/Broken); "Broken Promises"
  view powers the dashboard tile; promise-vs-actual comparison.

### 4.7 Sales Representative Management & Assignment (§11, Phase 3)
- Manage reps (code, territory, active); assign/unassign customers; view per-rep
  collection performance and targets. Role-gated to owner/manager.

### 4.8 Reports (§13)
- **Types:** Customer Statement · Outstanding · Aging · Collection · Credit Sales ·
  Customer-wise Receivable · Salesperson Collection · Daily Collection · Monthly Credit
  vs Collection · Promise-to-Pay Performance.
- **Filters:** date range, customer, salesperson, area, status, aging bucket.
- **Export:** Excel / CSV / PDF (async job → poll → signed download, per API §10).

### 4.9 User & Role Management (§6)
- Invite/add members with a role (owner/manager/sales_rep/collection_officer); change
  role/status. Owner-only for sensitive changes; enforced by RBAC and surfaced in UI
  (hidden/disabled controls, not just server 403).

### 4.10 Reminder Templates (§9, §34)
- Manage Bangla (and optional English) templates with variables; preview with sample data;
  channel (SMS/WhatsApp); delivery log with status/cost; low-credit warnings.

### 4.11 Subscription / Plan (§24)
- Current plan & status; compare Free/Pro/Business; change plan; billing period; feature
  gates reflect plan limits.

### 4.12 Business Settings
- Business profile, area/timezone/currency, quiet hours, consent defaults, data export &
  deletion requests (§36), language.

### 4.13 Audit Log (§15/§22)
- Filterable log of who changed what (create/update/reverse/login), before/after, IP, time.
  Read-only. Owner/sysadmin visibility.

## 5. Role → screen visibility (§6)

| Screen / action | Owner | Manager | Sales Rep | Collection Officer |
|---|---|---|---|---|
| Dashboard | ✔ | ✔ | assigned only | assigned only |
| Customers (all) | ✔ | ✔ | assigned only | assigned only |
| Record credit | ✔ | ✔ | ✔ | — |
| Record payment | ✔ | ✔ | — | ✔ |
| Collections / Promise | ✔ | ✔ | ✔ | ✔ |
| Reports | ✔ | ✔ | own | own |
| Users & Roles | ✔ | — | — | — |
| Subscription / Settings | ✔ | — | — | — |
| Audit Log | ✔ | view | — | — |

(UI hides or disables what the role can't do; the server still enforces it.)

## 6. Table, form & state patterns

- **Tables:** server pagination (limit ≤ 100), sortable headers, sticky header, money
  right-aligned tabular, status as pills, row actions in a trailing column.
- **Forms:** inline validation with the API's per-field error envelope (§21); optimistic
  UI only for non-financial edits.
- **Empty/loading/error:** skeleton rows; empty states with a primary action; errors show
  the API `error.message` and a retry.
- **Money:** rendered from string/decimal, never parsed as float in a way that loses precision.

## 7. Accessibility & performance

- Dashboard initial load < 3s under normal conditions (§23); heavy reports paginate/stream.
- Keyboard-navigable, visible focus, WCAG-AA contrast, theme-aware charts.

## 8. Acceptance (Web)

- A web user can view customers and transactions from the central DB and cannot access
  another business's data (§27).
- Every report supports its documented filters and exports to Excel/CSV/PDF.
- Role gating matches the table in §5 on both UI and API.
