# BakiBondhu — Android UI/UX Specification

**Version 1.0** · Companion to the Application Specification (v1.1)
Platform: Flutter + Dart · Target: low-end Android · Bangla-first · Offline-first

---

## 1. Purpose & scope

This document specifies every Android screen, its fields, states, actions, and
navigation, so the app can be built without further UX decisions. It covers the
field application only; the web app is specified separately. It implements the
modules in app-spec §7 and the screens in §8, plus the localization (§33),
messaging/consent (§34), and offline (§16–17) requirements.

## 2. Design principles (Android)

- **Bangla-first (§33).** Every label, button, empty state, and error is in Bangla;
  English is an optional secondary language. The whole core loop is completable
  without reading any English.
- **Offline is the baseline (§16).** No core screen blocks on the network. A
  persistent sync-state indicator is always visible.
- **One primary action per screen.** Big touch targets (≥ 48dp), thumb-reachable
  primary buttons, large glanceable numbers.
- **Collection is the hero.** Money owed and who to chase come first on every list.
- **Instant feel (§23).** Local save < 1s; local search < 500ms; home < 2s.

## 3. Design system

| Token | Value |
|---|---|
| Type — Bangla | Noto Sans Bengali (bundled; verify conjuncts on low-end devices, §33) |
| Type — numerals | Tabular figures; Bengali-numeral display mode optional (§33) |
| Currency | ৳ prefix, lakh grouping (e.g. ৳1,24,500) |
| Primary color | Taka-green (collection/positive) |
| Semantic | Overdue = warning/critical stripe; paid/settled = success; never color-only (pair with label) |
| Touch target | ≥ 48dp; primary buttons full-width |
| Motion | Minimal; respect system reduce-motion |
| Empty states | One gentle Bangla prompt + a single primary action |

## 4. Navigation map

```
Splash → (auth?) → Login/OTP ─┬─ first run → Business Setup
                              └─ Home Dashboard
Home ├─ Customer List ── Customer Detail ─┬─ Add/Record Credit
     │                                    ├─ Add/Record Payment
     │                                    ├─ Reminder Preview → OS SMS/WhatsApp
     │                                    ├─ Collection Activity
     │                                    └─ Promise-to-Pay
     ├─ Add Customer
     ├─ Reports / Summary
     ├─ Sync Center
     └─ Profile & Settings
```

Bottom navigation (4 tabs): **হোম** (Home) · **কাস্টমার** (Customers) · **রিপোর্ট**
(Reports) · **সেটিংস** (Settings). A persistent sync chip sits in the app bar.

## 5. Screen specifications

Each screen lists: purpose · key elements · primary action · states · offline behavior.

### 5.1 Splash / Initialization
- **Purpose:** load session, open local DB, decide route.
- **Elements:** logo (বাকিবন্ধু), version.
- **Route:** valid session → Home; else → Login. Never blocks on network.

### 5.2 Login / Authentication (§8.1, §38)
- **Elements:** identifier (mobile/email/username), password; **OR** phone + OTP path
  (primary for field users, §38); "Remember session"; "Forgot password".
- **Primary action:** **লগ ইন** / **OTP দিন**.
- **States:** idle · submitting · error (invalid credentials / OTP expired / offline).
- **Offline:** if a valid cached session exists, allow entry to local data; block only
  actions that require the server. Optional app-lock PIN/biometric (§38).

### 5.3 Business Setup (first run)
- **Purpose:** create the business in ≤ 3 minutes; no signup wall before first value (§33).
- **Elements:** business name (required), area (optional), currency (default BDT),
  timezone (default Asia/Dhaka). Owner role assigned automatically.
- **Primary action:** **ব্যবসা তৈরি করুন** → Home with an "add your first customer" prompt.

### 5.4 Home Dashboard (§8.2)
- **Elements (tiles):** Total Receivable · Overdue Amount · Due Today · Customers with
  Outstanding · Collected Today · Collection Rate · **Top Collection Priorities** list.
- **Quick actions:** Add Customer · **বাকি দিলাম** (Give Baki) · **টাকা পেলাম** (Receive
  Payment) · **মনে করান** (Reminder).
- **Sync indicator:** SYNCED / PENDING (n) / OFFLINE / FAILED, tappable → Sync Center.
- **Offline:** all tiles computed from local SQLite; figures marked "last synced …" when stale.

### 5.5 Customer List (§8.3)
- **Elements:** search (name/mobile/customer code); filter chips (Outstanding / Paid /
  Overdue / Due Today); sort (balance ▼ default, name, last transaction, overdue days);
  each row: name · **balance (prominent)** · aging hint · quick pay/reminder icons.
- **Primary action:** **+ নতুন কাস্টমার**.
- **Offline:** full list and search work offline (§16).

### 5.6 Add / Edit Customer (§8.4)
- **Fields:** Name (required) · Mobile · Alternative contact · Address · Area/Territory ·
  Customer type · Credit limit · Default due days · Assigned sales rep · Notes ·
  **Messaging consent toggle** (§34, default off) · Active/Inactive.
- **Primary action:** **সেভ করুন**. Name-only is enough to save; everything else optional.
- **Data quality (§40):** on save, warn if the same phone/name already exists (merge suggestion).
- **Offline:** created locally with `local_id`/`device_id`, `sync_status = PENDING`.

### 5.7 Customer Detail (§8.5)
- **Header:** name + phone (tap to call); current outstanding balance (large).
- **Rollups:** total credit · total paid · overdue amount · oldest outstanding date.
- **Tabs/sections:** Transaction history · Collection history · Promise-to-Pay history
  (newest first, read-only).
- **Three actions:** **বাকি দিলাম** · **টাকা পেলাম** · **মনে করান**.
- **Offline:** balances recomputed locally from the ledger.

### 5.8 Record Credit — বাকি দিলাম (§8.6)
- **Fields:** amount (big number pad, required > 0) · date/time (default now) · due date /
  due days (default from customer) · invoice/reference · note. Created-by + offline id captured.
- **Primary action:** **সেভ করুন** → back to detail with updated balance.
- **Rule:** append-only; never edited/deleted (§15).

### 5.9 Record Payment — টাকা পেলাম (§8.7)
- **Fields:** amount (required > 0) · date/time · payment method · reference · note ·
  collected-by · receipt/reference where required.
- **Rule:** if payment would exceed outstanding and overpayment is disabled → block with a
  clear Bangla message (§15). On save, allocate FIFO to oldest credits (see Sync/DB).
- **Primary action:** **সেভ করুন**.

### 5.10 Reminder Preview (§9, §34)
- **Elements:** recipient name/number; pre-filled Bangla message with resolved variables
  ({customer_name},{balance},{due_amount},{due_date},{business_name}); editable body.
- **Actions:** **SMS পাঠান** · **WhatsApp** (OS intent in Free tier; gateway for paid,
  §34). Merchant presses send.
- **Consent guard (§34):** blocked if `do_not_message` or no consent; prompt to capture
  consent or add a number first.

### 5.11 Collection Activity (§8.8)
- **Fields:** contact date/time · method (phone/visit/message/other) · status
  (Not Contacted / Contacted / Promise to Pay / Partially Paid / Paid / Refused-Disputed /
  Follow-up Required) · note · next follow-up date.
- **Offline:** created locally; syncs later.

### 5.12 Promise-to-Pay (§8.9)
- **Fields:** promised amount · promise date · customer note · follow-up date · actual
  payment · status (Open / Fulfilled / Partial / Broken).
- **Offline:** carries sync fields (added to schema during review).

### 5.13 Reports / Summary
- Mobile-friendly summaries: outstanding, aging (0–7/8–30/31–60/61–90/90+), daily
  collection, top outstanding. Full reporting lives on web (§13); Android shows read
  summaries and a customer statement share/export.

### 5.14 Sync Center (§16–17)
- **Elements:** counts by state (LOCAL/PENDING/SYNCED/FAILED/CONFLICT); last sync time;
  **Sync Now** button; per-item error list; **conflict review** screen (§37).
- **Conflict review:** shows the local vs server record; every resolution is audited;
  financial amounts are never silently overwritten.

### 5.15 Profile & Settings
- Language (Bangla/English), Bengali-numeral toggle, quiet hours & notification prefs
  (§35), app-lock PIN/biometric (§38), business switch (multi-business users), data
  export request (§36), logout.

## 6. Global states & patterns

- **Loading:** skeletons, never blank; core reads come from local DB so loads are instant.
- **Empty:** one Bangla line + one primary action (e.g. "প্রথম বাকি যোগ করুন").
- **Error:** plain-language Bangla; says what went wrong and the next step (§copy rules).
- **Offline banner:** non-blocking; shows pending count and Sync Now.
- **Confirm on irreversible-feeling actions** (reverse a transaction, deactivate a customer).

## 7. Accessibility & performance

- Large type, high contrast, daylight-readable; never rely on color alone.
- Cold start → usable Home < 2s; local search < 500ms; local save < 1s (§23).
- Verified on a genuine ৳5–8k low-RAM device, including Bangla conjunct rendering (§33).

## 8. Acceptance (UI)

- Core loop (add customer → credit → payment → balance → reminder) completable in Bangla,
  offline, with no training, first customer within ~3 minutes (§27, §33).
- Every screen renders correctly at 320dp width without horizontal scrolling.
- Sync state is visible from every top-level screen.
