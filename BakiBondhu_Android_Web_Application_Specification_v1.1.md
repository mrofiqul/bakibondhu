# BakiBondhu — Android & Web Application Specification

**Version 1.1** · Product & Technical Specification · Markdown companion to the `.docx`

---


## 1. Document Purpose

This document defines the functional, technical, database, API, security, synchronization, reporting, and deployment requirements for BakiBondhu as two applications: an Android mobile application and a web application. Both applications will use one shared backend/API and central database.

## 2. Product Vision

BakiBondhu is a collection-first receivables management platform for Bangladeshi micro-merchants, wholesalers, and distributors. The product should make it fast to record credit sales and payments, understand who owes money, prioritize collections, and follow up with customers.
Core loop: Add Customer → Record Credit → Record Payment → Check Balance → Follow Up / Nudge.

## 3. Target Users

- Micro-merchants and small retailers
- Wholesalers and distributors
- Business owners
- Managers
- Sales representatives
- Collection officers
- System administrators

## 4. Application Architecture

Recommended architecture:
- Android App: Flutter + Dart
- Local Android database: SQLite
- Web App: React + TypeScript
- Backend: ASP.NET Core Web API
- Central database: PostgreSQL
- Authentication: JWT access token + refresh token
- Communication: REST API over HTTPS
- Offline synchronization: Local queue + background sync
- Hosting: Cloud VPS/Azure/AWS or equivalent managed infrastructure
High-level flow:
Android App ↔ REST API ↔ PostgreSQL
Web App ↔ REST API ↔ PostgreSQL
Android App ↔ SQLite for offline operation

## 5. Multi-Tenant Business Model

- Every business receives a unique Business ID.
- All business data must be isolated by Business ID.
- A user can belong to one or more businesses depending on the subscription/role model.
- Every customer, transaction, collection activity, and report must be filtered by Business ID.
- No API endpoint may return data belonging to another business.

## 6. User Roles & Permissions

Business Owner: Full business access, users, customers, transactions, collections, reports, settings, subscription.
Manager: Customers, transactions, collections, reports, staff monitoring.
Sales Representative: Assigned customers, credit transactions, customer information, collection follow-up.
Collection Officer: Assigned customers, payment recording, collection activities, promise-to-pay, follow-up.
System Administrator: Platform-level administration, support, plans, audit and system monitoring.

## 7. Android Application – Main Modules

- Splash / App Initialization
- Login / Authentication
- Business Setup
- Home Dashboard
- Customer Management
- Customer Detail
- Credit Transaction
- Payment Transaction
- Transaction History
- Collection Activities
- Promise-to-Pay
- Reminders
- Reports / Summary
- Profile & Settings
- Offline Sync Center

## 8. Android Screen Specifications


### 8.1 Login

- Mobile/email/username
- Password
- Remember session
- Forgot password
- Login error handling
- Offline session handling where appropriate

### 8.2 Home Dashboard

- Total Receivable
- Overdue Amount
- Due Today
- Customers with Outstanding Balance
- Collected Today
- Collection Rate
- Top Collection Priorities
- Quick actions: Add Customer, Give Baki, Receive Payment, Reminder
- Offline/sync status indicator

### 8.3 Customer List

- Search by name, mobile, customer code
- Filter: Outstanding / Paid / Overdue / Due Today
- Sort by balance, customer name, last transaction, overdue days
- Customer balance shown prominently
- Quick payment and reminder actions

### 8.4 Add Customer

- Customer Name – required
- Mobile Number
- Alternative Contact
- Address
- Area/Territory
- Customer Type
- Credit Limit
- Default Due Days
- Assigned Sales Representative
- Notes
- Active/Inactive status

### 8.5 Customer Detail

- Customer profile
- Current outstanding balance
- Total credit
- Total paid
- Overdue amount
- Oldest outstanding date
- Transaction history
- Collection history
- Promise-to-pay history
- Quick actions: Baki দিলাম, টাকা পেলাম, মনে করান

### 8.6 Credit Transaction

- Customer
- Amount
- Date/time
- Invoice/reference number
- Note
- Due date / due days
- Created by user
- Offline transaction ID
Financial transactions must not be physically deleted. Corrections should use reversal or adjustment transactions with an audit trail.

### 8.7 Payment Transaction

- Customer
- Payment amount
- Payment date/time
- Payment method
- Reference
- Note
- Collected by
- Receipt/reference number where required

### 8.8 Collection Activity

- Customer
- Contact date/time
- Contact method: phone, visit, message, other
- Status: Not Contacted, Contacted, Promise to Pay, Partially Paid, Paid, Refused/Disputed, Follow-up Required
- Notes
- Next follow-up date

### 8.9 Promise-to-Pay

- Promised amount
- Promise date
- Customer note
- Follow-up date
- Actual payment
- Promise status: Open, Fulfilled, Partial, Broken

## 9. Reminder System

- Bangla reminder templates
- Optional English templates
- Customer name variable
- Outstanding balance variable
- Due amount variable
- Due date variable
- Business name variable
- Reminder history/log
- Manual reminder trigger
- Scheduled reminder capability for paid plans
Example variables: {customer_name}, {balance}, {due_amount}, {due_date}, {business_name}.

## 10. Receivables & Collection Intelligence

- Aging buckets: 0–7, 8–30, 31–60, 61–90, 90+ days
- Outstanding amount by customer
- Days overdue
- Payment frequency
- Payment behavior
- Promise-to-pay history
- Collection priority score
- Customers requiring follow-up
- Customers with broken promises
- Largest outstanding customers
Collection priority should combine outstanding amount, overdue duration, payment behavior, and promise-to-pay history. The scoring formula should be configurable in a later release.

## 11. Web Application – Main Modules

- Login & Authentication
- Business Dashboard
- Customer Management
- Receivables
- Collections
- Promise-to-Pay
- Sales Representative Management
- Customer Assignment
- Reports
- User & Role Management
- Reminder Templates
- Subscription / Plan
- Business Settings
- Audit Log

## 12. Web Dashboard

- Total Credit Sales
- Total Receivable
- Collected This Month
- Overdue Amount
- Customers with Outstanding
- Collection Rate
- Top Outstanding Customers
- Top Collection Priorities
- Broken Promises
- Recent Transactions

## 13. Web Reports

- Customer Statement
- Customer Outstanding Report
- Aging Report
- Collection Report
- Credit Sales Report
- Customer-wise Receivable
- Salesperson-wise Collection
- Daily Collection
- Monthly Credit vs Collection
- Promise-to-Pay Performance
- Export formats: Excel, CSV, PDF
- Reports must support date range, customer, salesperson, area, status, and aging filters.

## 14. Dashboard Charts

- Receivable Aging
- Credit vs Collection
- Outstanding Trend
- Top 10 Outstanding Customers
- Collection Performance
- Promise-to-Pay vs Actual Collection

## 15. Core Business Rules

- Customer balance = Total Credit − Total Payment + Adjustments/Reversals.
- The transaction engine is the single source of truth for customer balances.
- Payment cannot silently exceed outstanding balance; configurable overpayment handling is required.
- Financial transactions are append-only.
- Reversal/adjustment must preserve the original transaction and record who performed the correction.
- All financial timestamps must be stored consistently and displayed in Bangladesh local time.
- Every financial transaction must belong to a business and customer.

## 16. Offline-First Android Requirements

- Customer list available offline
- Customer search available offline
- Record credit offline
- Record payment offline
- View balance offline
- View transaction history offline
- Create collection activity offline
- Queue unsynchronized transactions
- Automatic background synchronization when internet returns
- Manual Sync Now option

## 17. Synchronization Model

- LOCAL – created/updated locally
- PENDING – waiting for upload
- SYNCED – successfully synchronized
- FAILED – synchronization failed
- CONFLICT – requires conflict handling
Important sync fields: local_id, server_id, created_at, updated_at, sync_status, device_id, user_id, business_id.
Use an append-only/event-oriented transaction approach where possible. Avoid blind last-write-wins for financial transactions.

## 18. Proposed Database Tables

- businesses
- users
- business_users
- roles
- customers
- customer_contacts
- transactions
- transaction_types
- collection_activities
- promise_to_pay
- reminder_templates
- reminder_logs
- sales_representatives
- customer_assignments
- devices
- sync_logs
- audit_logs
- subscriptions
- plans

## 19. Transaction Data Structure

- transaction_id
- local_id
- business_id
- customer_id
- transaction_type
- amount
- transaction_date
- due_date
- invoice_reference
- payment_method
- note
- created_by
- device_id
- created_at
- updated_at
- sync_status
- reversal_of_transaction_id

## 20. API Specification – High-Level

- /api/v1/auth
- /api/v1/business
- /api/v1/users
- /api/v1/customers
- /api/v1/transactions
- /api/v1/receivables
- /api/v1/collections
- /api/v1/promises
- /api/v1/reminders
- /api/v1/reports
- /api/v1/dashboard
- /api/v1/sync
- /api/v1/subscriptions

## 21. API Design Requirements

- RESTful JSON API
- Versioned endpoints
- JWT authentication
- Standard HTTP status codes
- Consistent validation/error response structure
- Pagination for large lists
- Server-side filtering and sorting
- Idempotency for transaction synchronization
- Audit information for sensitive actions
- Rate limiting on authentication and public endpoints

## 22. Security Requirements

- HTTPS only
- JWT access token + refresh token
- Secure password hashing
- Role-based access control
- Business/tenant-level data isolation
- Secure Android token storage
- Input validation and sanitization
- Rate limiting
- Audit logs
- Database backups
- Restricted database access
- Encryption at rest where supported
- Session/token expiration and revocation
- No sensitive credentials stored in source code

## 23. Performance Requirements

- Android local home screen: target under 2 seconds
- Local customer search: target under 500 ms
- Credit/payment save locally: target under 1 second
- Web dashboard initial load: target under 3 seconds under normal conditions
- Large reports must use server-side pagination/filtering
- Database indexes required for business_id, customer_id, transaction_date, due_date and commonly filtered fields

## 24. Subscription Concept

- Free: customer management, basic credit/payment ledger, balance and basic history
- Pro: advanced reminders, aging, collection tools, richer reports, multi-user features
- Business: staff management, salesperson/territory tools, advanced analytics and higher limits
Indicative pricing to validate with pilot customers: Pro approximately ৳199–299/month; Business approximately ৳999–2,999/month.

## 25. Development Phases


### Phase 1 – MVP

- Android core application
- Authentication
- Business setup
- Customer management
- Credit/payment transactions
- Balance and history
- Offline SQLite
- Backend API
- PostgreSQL
- Basic web dashboard
- Basic customer/transaction management

### Phase 2 – Collection Management

- Aging
- Collection priority
- Collection activities
- Promise-to-pay
- Follow-up
- Collection dashboard
- Staff assignment

### Phase 3 – Distributor Edition

- Sales representatives
- Territories
- Retailer assignment
- Collection targets
- Sales/collection performance

### Phase 4 – Merchant Intelligence

- Payment behavior analysis
- Customer segmentation
- Risk indicators
- Collection recommendations
- Collection prediction

### Phase 5 – Financial Ecosystem

- Potential lending/referral integrations
- Supplier ordering
- Additional financial services
Financial ecosystem features should only be introduced after product-market fit, operational readiness, and applicable regulatory review.

## 26. Testing Requirements

- Unit testing – business logic and calculations
- API integration testing
- Database testing
- Android UI testing
- Web UI testing
- Offline/online synchronization testing
- Conflict and retry testing
- Role/permission testing
- Security testing
- Performance testing
- Backup/restore testing
- Real-device testing on low-end Android phones

## 27. Acceptance Criteria – MVP

- A user can create a business and log in.
- A user can create, edit and deactivate customers.
- A user can record credit without internet.
- A user can record payment without internet.
- Customer balance is calculated correctly.
- Offline transactions synchronize automatically when internet returns.
- Duplicate transaction creation is prevented during retry.
- A user can view customer transaction history.
- A user can see total receivables on the dashboard.
- A web user can view customers and transactions from the central database.
- Users cannot access another business's data.
- Financial transaction corrections preserve an audit trail.

## 28. Recommended Project Structure


### 28.1 Backend

- BakiBondhu.Api
- BakiBondhu.Application
- BakiBondhu.Domain
- BakiBondhu.Infrastructure
- BakiBondhu.Tests

### 28.2 Android

- core
- data
- domain
- features/auth
- features/dashboard
- features/customers
- features/transactions
- features/collections
- features/reminders
- features/settings
- sync

### 28.3 Web

- src/components
- src/pages
- src/features
- src/services
- src/hooks
- src/types
- src/utils
- src/auth

## 29. Important Product Decisions

- The Android application is the primary field application and must work reliably with weak/no internet.
- The web application is the management, reporting, monitoring and administration interface.
- Both applications must use the same business rules through the backend.
- The backend must be the authoritative source for synchronized data.
- The local Android database is an offline working store, not the permanent central source.
- Financial records must be append-only with reversal/adjustment rather than deletion.
- The product should prioritize collection workflow over becoming a full accounting/POS system in the first releases.

## 30. Future Enhancements

- Bangla voice-based transaction entry
- WhatsApp/SMS automation
- Receipt generation
- Customer self-service statement
- Customer payment links
- Advanced collection scoring
- AI-assisted collection recommendations
- Salesperson mobile workflow
- Distributor analytics
- Third-party payment/financial integrations

## 31. Final Product Direction

The recommended long-term positioning is not simply a digital khata. BakiBondhu should evolve into a Merchant Receivables & Collection Assistant and, for larger users, a Receivables Management / Distributor Operating System.
The product roadmap should therefore move from Digital Baki Ledger → Collection Assistant → Receivables Management → Distributor Operating System → Merchant Intelligence → Financial Ecosystem.

## 32. Immediate Next Specifications

- Complete PostgreSQL Database Specification with fields, data types, keys and indexes
- Complete REST API Specification with request/response JSON examples
- Complete Android UI/UX Specification for every screen
- Complete Web UI/UX Specification for every screen
- Development Folder & Coding Standards
- Offline Synchronization Technical Design
- Test Case / QA Specification
- Deployment & DevOps Specification
The following sections (33–42) were added during a specification review to close gaps in localization, messaging/consent, privacy and compliance, sync-conflict handling, authentication, analytics, support, and scope sequencing.

## 33. Localization & Bangla-First UX

The application must be Bangla-first across the entire interface, not only in reminder templates.
- Full UI available in Bangla; English as an optional secondary language.
- Taka (৳) is the only currency, with consistent lakh-style grouping (e.g., ৳1,24,500) and an optional Bengali-numeral display mode.
- Bundle Noto Sans Bengali and verify conjunct rendering on low-end Android devices.
- Large touch targets, plain language, and minimal steps for low-literacy, non-technical users.
- Frictionless first run: the shopkeeper reaches value within ~3 minutes; no signup wall before the first customer or transaction; phone number optional at first.

## 34. Messaging, Consent & Delivery

Reminders depend on external messaging channels; integration, cost, and consent must be specified.
- SMS/WhatsApp gateway integration with delivery status (queued, sent, delivered, failed).
- Per-message and per-business credit/cost accounting, with low-credit warnings before sends fail.
- Capture customer consent before messaging; support per-customer opt-out and a global do-not-message list.
- Respect quiet hours and sending rate limits to avoid spam classification.
- A reminder must never expose another customer's data; templates are limited to the recipient's own balance.

## 35. In-App & Push Notifications

- Merchant notifications for: due today, overdue threshold crossed, promise-to-pay follow-up due, and sync failure.
- Per-user configurable; delivered in Bangladesh local time and respecting quiet hours.

## 36. Data Ownership, Privacy & Compliance

- The merchant can export their full business data (CSV/Excel/PDF) and request account and data deletion.
- Collect only the customer PII required for collection (name, phone); document why each stored field is needed.
- Provide a privacy policy and terms of service, and keep consent records.
- Align with applicable Bangladesh data-protection and telecom messaging regulations; obtain regulatory review before any payment or lending features (see Phase 5).
- Define a data retention and archival policy for closed accounts and historical transactions.

## 37. Synchronization Conflict Handling

The append-only model makes conflicts rare, but their handling must be explicit.
- The server is authoritative for identity and duplicate detection; transaction amounts are never silently overwritten.
- CONFLICT items are surfaced to the user in a clear review screen, and every resolution is audited.
- A server-side idempotency/deduplication window keyed on local_id + device_id prevents duplicate transactions on retry.

## 38. Authentication for Field Users

- Support phone-number + OTP login in addition to password — more natural for Bangladeshi merchants and field staff.
- Optional PIN or biometric app-lock for the offline field application.
- Session persistence tuned for weak-connectivity field use, with secure token storage.

## 39. Product Analytics & Retention Measurement

Retention is the core success signal and must be measurable from day one.
- Track daily-active merchants and whether each merchant's overdue baki decreases over time.
- Measure onboarding completion, feature adoption, and reminder-to-payment conversion.
- Analytics must be privacy-respecting and opt-out; no customer PII in analytics events.

## 40. Data Quality

- Duplicate-customer detection (same phone or name) with a merge suggestion.
- Validation for phone formats and amount ranges to guard against accidental large or mistyped entries.

## 41. Support, Updates & Distribution

- In-app help/FAQ in Bangla and a simple support channel (e.g., WhatsApp or phone).
- Google Play distribution with app versioning and a forced-update path for breaking sync or schema changes.
- Crash and error reporting plus basic observability (coordinate with the Deployment/DevOps specification).

## 42. Scope & Sequencing Recommendation

This specification is strong as a long-term blueprint. For a solo, pre-revenue build, the Phase 1 MVP in Section 25 is heavy (backend API + PostgreSQL + web dashboard + multiple roles).
- Validate demand first (20–30 merchant interviews) before committing to the full stack.
- Ship an offline-first, Android-only, local-first MVP built around the core loop; add the ASP.NET Core/PostgreSQL backend and web app once daily-use retention is proven.
- Confirm the role model (owner, manager, sales representative, collection officer) against the first target vertical before building every role.
- Keep distributor, sales-representative, and collection-officer features in later phases, as already sequenced in Section 25.

