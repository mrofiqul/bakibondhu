# 03 · Screens

Five screens, plus first-run. Big touch targets, Bangla-first, **one clear
action per screen.** Sample data below is illustrative (নমুনা তথ্য), not a real
merchant's figures.

Design rules that apply to every screen:

- Minimum touch target ~48dp; primary buttons full-width and thumb-reachable.
- Numbers large and glanceable; Bangla labels, Bangla numerals acceptable in
  display, Western digits acceptable in entry (finalize in design + Phase 0).
- Never require horizontal scrolling. Long lists scroll vertically only.
- Every destructive-feeling action confirms; every core action is one tap.

---

## Screen 1 · Home — "money out there"

**Purpose:** the merchant sees, in one glance, how much money is owed to them and
who to chase first.

| Element | Detail | Ref |
|---------|--------|-----|
| Headline total | One big number — **মোট বাকি (আপনার পাওনা)** = total owed across everyone | [FR-4.2](02-functional-spec.md) |
| Customer count | e.g. "১৮ জন কাস্টমার" | FR-4.6 |
| Customer list | Sorted by amount owed, biggest / oldest first | FR-4.4 |
| List row | Name + balance + aging hint (e.g. "১২ দিন পার"), tap to open detail | FR-4.5 |
| Primary action | Big **+ নতুন কাস্টমার** button | FR-1 |

Empty state (first run): one gentle "add your first বাকি" prompt → add-customer.

---

## Screen 2 · Customer detail

**Purpose:** everything about one customer, and the three things the merchant
does with them.

| Element | Detail | Ref |
|---------|--------|-----|
| Header | Customer name + phone (tappable to call), back chevron | — |
| Balance | Running balance at top — **এখন বাকি ৳45,000** | FR-4.1 |
| History | Every বাকি & payment, newest first, with amount/date/note | FR-6 |
| Action 1 | **বাকি দিলাম** (record credit) | FR-2 |
| Action 2 | **টাকা পেলাম** (record payment) | FR-3 |
| Action 3 | **মনে করান** (open reminder) | FR-5 |

The three actions are the screen's reason to exist — large, always visible.

---

## Screen 3 · Add transaction

**Purpose:** record a credit or payment in seconds.

| Element | Detail | Ref |
|---------|--------|-----|
| Type toggle | **বাকি দিলাম / টাকা পেলাম** — one is always selected | FR-2 / FR-3 |
| Amount | Big number pad, large display (e.g. ৳12,000). Required, > 0 | FR-2.1 |
| Date | Defaults to **আজ** (today); editable | FR-2.2 |
| Note | Optional, short (e.g. "চাল, ডাল") | FR-2.2 |
| Primary action | **সেভ করুন** → one tap to save, returns to detail | FR-2.4 |

Number pad layout: 1–9, `.`, 0, `⌫`. Amount is the visual focus of the screen.

---

## Screen 4 · Add customer

**Purpose:** create a party with the absolute minimum friction.

| Element | Detail | Ref |
|---------|--------|-----|
| Name | **নাম \*** — required | FR-1.1 |
| Phone | **মোবাইল নম্বর** — optional, encouraged | FR-1.1 |
| Nudge copy | "নম্বর থাকলে এক চাপে বাকির কথা মনে করিয়ে দিতে পারবেন। ঠিকানা বা ছবি লাগবে না।" | FR-1.2 |
| Primary action | **যোগ করুন** | FR-1.4 |

That's the entire screen — no address, no photo, no category. On purpose.

---

## Screen 5 · Reminder preview

**Purpose:** a polite, one-tap Bangla nudge — the feature the khata apps treat as
an afterthought and we treat as the point.

| Element | Detail | Ref |
|---------|--------|-----|
| Recipient | Customer name + phone | FR-5.1 |
| Message | Pre-filled polite Bangla, name + amount injected (see template) | FR-5.1 |
| Edit | "✎ পাঠানোর আগে বদলাতে পারেন" — message editable | FR-5.2 |
| Action A | **SMS পাঠান** → opens OS SMS composer, pre-filled | FR-5.3 |
| Action B | **WhatsApp** → opens WhatsApp intent, pre-filled | FR-5.3 |

Pre-filled template (name + amount substituted, shop name from settings):

```
আসসালামু আলাইকুম [নাম] ভাই। আপনার কাছে আমার দোকানে ৳[পরিমাণ] বাকি আছে।
সুবিধামতো একটু পরিশোধ করলে উপকৃত হতাম। ধন্যবাদ — [দোকানের নাম]।
```

See [05-reminders](05-reminders.md) for edge cases and the no-phone path.

---

## First-run / onboarding (not a numbered screen)

- No signup wall; open → add first customer immediately. ([FR-7](02-functional-spec.md))
- Optional shop name captured once (used in the reminder signature); can be
  skipped and set later.
- Empty Home shows a single "add your first বাকি" prompt.
- Target: usable and recording in **under 3 minutes**, no training, no English.

---

## Screen map

```
        ┌──────────────┐
        │  First run   │  (once)
        └──────┬───────┘
               ▼
        ┌──────────────┐   + নতুন কাস্টমার    ┌──────────────┐
        │  1. Home     │ ───────────────────▶ │ 4. Add       │
        │  total owed  │ ◀─────────────────── │    customer  │
        └──────┬───────┘      যোগ করুন        └──────────────┘
               │ tap a customer
               ▼
        ┌──────────────┐   বাকি দিলাম /       ┌──────────────┐
        │ 2. Customer  │   টাকা পেলাম         │ 3. Add       │
        │    detail    │ ───────────────────▶ │  transaction │
        │              │ ◀─────────────────── │              │
        └──────┬───────┘      সেভ করুন        └──────────────┘
               │ মনে করান
               ▼
        ┌──────────────┐
        │ 5. Reminder  │ ──▶ OS SMS / WhatsApp
        │    preview   │
        └──────────────┘
```
