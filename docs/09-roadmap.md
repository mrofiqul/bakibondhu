# 09 · Roadmap

## 9.1 Where v1 sits

```
PHASE 0        PHASE 1              PHASE 2            PHASE 3
Validate       Build MVP            50 users           Monetise
wk 1–3         wk 4–10              wk 11–16           mo 5+
interviews →   THIS SPEC       →    daily use &   →    paid reminders,
pick vertical  5 screens, offline   retention proof    pro tools → markets
```

This document specifies **Phase 1 only.** Phase 0 must confirm the collection
pain (or reshape the vertical) **before** the first line of app code.

## 9.2 v1 build sequence (weeks 4–10)

| When | Work | Done when |
|------|------|-----------|
| **Week 4** | Data + logic first. SQLite tables, add customer, add transaction, compute balance. Ugly UI is fine. | The money math is provably correct ([AC-3](08-acceptance-criteria.md)); pure domain logic unit-tested. |
| **Week 5** | Screens 1 & 2 end-to-end in Bangla. Home total + customer detail on a real device. | You can add a customer, record বাকি/payment, and see correct balances on Home and detail. |
| **Week 6** | Reminder + polish. SMS/WhatsApp intent, empty states, the 3-minute first-run. **Feature-complete v1.** | All five screens work; reminder pre-fills name + amount ([AC-4](08-acceptance-criteria.md)). |
| **Week 7** | Test on 2–3 cheap Androids. Fix crashes & Bangla rendering. Hand to 3 friendly merchants from Phase 0. | Passes the release acceptance criteria ([08](08-acceptance-criteria.md)) on real low-end hardware. |
| **Weeks 8–10** | Iterate on real use (this bleeds into Phase 2). Change **only** what you watch merchants struggle with. | Merchants use it unprompted the next day ([08](08-acceptance-criteria.md) §8.1). |

**Constraints:** built solo, ৳0 / free tier, target cheap Android, ship ~Week 10.

## 9.3 What comes after v1 (not specced here)

Deferred deliberately; each earns its place only when real usage demands it.

| Phase | Candidate work | Gate |
|-------|----------------|------|
| Fast-follow | Local backup/export; "last reminded" timestamp; simple data safety before merchants accumulate months of data | Retention showing; risk of data loss real |
| Phase 3 · Monetise | **Paid bulk/scheduled reminders** (SMS gateway, pass-through + margin), multi-shop, party-wise pro reports | Proven daily use **and** validated willingness to pay ৳150–250/mo |
| Later | Cloud sync/backup (Supabase/Firebase); SME-lending referrals; supplier re-ordering | Merchants rely on the app; business model proven |
| New markets | Localize language + payment rails market by market (India, Pakistan, Nigeria, Indonesia…) | Retention proven at home first |

> **Reminder for the business model:** the Phase 3 paid-reminder feature is a
> *different build* from v1's free, merchant-triggered reminder. It also needs an
> SMS gateway whose real per-message cost (especially masked/transactional SMS in
> Bangladesh) should be validated — it feeds both the cost line and the margin.
> Confirm willingness to pay in Phase 0 interviews; it is the single unproven
> assumption the whole model rests on.

## 9.4 Your move before any code

Don't open the editor first. Phase 0 comes first: interview 20–30 merchants, log
them in the Merchant Tracker, and let their real words and numbers confirm — or
redirect — this spec. Everything after Phase 0 is execution; the plan lives or
dies on what merchants actually tell you.
