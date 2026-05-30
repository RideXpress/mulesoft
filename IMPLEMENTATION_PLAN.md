# RideXpress - MuleSoft Implementation Plan

> **Monorepo** for all RideXpress MuleSoft API implementations following **API-led connectivity** architecture.
>
> _Last updated: March 2026_
>
> 📖 **Reference documentation**: [RideXpress/docs](https://github.com/RideXpress/docs)

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Use Cases](#use-cases)
- [API Application Catalog](#api-application-catalog)
- [Repository Structure](#repository-structure)
- [Phase 1 — Experience API (ridexpress-experience-api)](#phase-1--experience-api-ridexpress-experience-api)
- [Phase 2 — Database System API (database-system-api)](#phase-2--database-system-api-database-system-api)
- [Phase 3 — Process APIs](#phase-3--process-apis)
- [Phase 4 — System APIs (External Integrations)](#phase-4--system-apis-external-integrations)
- [Phase 5 — Cross-Cutting Concerns](#phase-5--cross-cutting-concerns)
- [Database Schema](#database-schema)
- [Integration Infrastructure](#integration-infrastructure)
- [CI/CD Pipeline](#cicd-pipeline)
- [Conventions & Best Practices](#conventions--best-practices)

---

## Architecture Overview

RideXpress follows the **MuleSoft API-led connectivity** model with three layers:

```
┌─────────────────────────────────────────────────────────┐
│                   EXPERIENCE LAYER                       │
│            ridexpress-experience-api                      │
│    (Mobile App / Web Frontend facing endpoints)          │
└────────────────────────┬────────────────────────────────┘
                         │  HTTP / AMQP
┌────────────────────────▼────────────────────────────────┐
│                    PROCESS LAYER                         │
│  ┌──────────────────┐ ┌───────────────────┐             │
│  │ request-ride     │ │ user-sign-up      │             │
│  │ process-api      │ │ process-api       │             │
│  ├──────────────────┤ ├───────────────────┤             │
│  │ accept-ride      │ │ waiting-ride      │             │
│  │ process-api      │ │ process-api       │             │
│  ├──────────────────┤ ├───────────────────┤             │
│  │ finish-ride      │ │ rides-process     │             │
│  │ process-api      │ │ async-api         │             │
│  └──────────────────┘ └───────────────────┘             │
└────────────────────────┬────────────────────────────────┘
                         │  HTTP / AMQP
┌────────────────────────▼────────────────────────────────┐
│                    SYSTEM LAYER                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │
│  │ db       │ │ okta     │ │ google   │ │ square    │  │
│  │ system   │ │ system   │ │ maps     │ │ system    │  │
│  │ api      │ │ api      │ │ system   │ │ api       │  │
│  │          │ │          │ │ api      │ │           │  │
│  ├──────────┤ ├──────────┤ ├──────────┤ ├───────────┤  │
│  │ gmail    │ │salesforce│ │ apple    │ │           │  │
│  │ system   │ │ system   │ │ push     │ │           │  │
│  │ api      │ │ api      │ │ notif.   │ │           │  │
│  │          │ │          │ │ api      │ │           │  │
│  └──────────┘ └──────────┘ └──────────┘ └───────────┘  │
└─────────────────────────────────────────────────────────┘
                         │
           ┌─────────────┼──────────────┐
           ▼             ▼              ▼
      PostgreSQL     RabbitMQ     External APIs
                                  (Okta, Google,
                                   Square, etc.)
```

> 📐 **Full API-led architecture diagram**: [ride-express-api-led.drawio.svg](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/api-led/ride-express-api-led.drawio.svg)
>
> 📐 **Solution diagram**: [solution-diagram.drawio.svg](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/entity-diagrams/solution-diagram.drawio.svg)
>
> 📐 **Integration context diagram**: [integration-context-diagram.drawio.svg](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/entity-diagrams/integration-context-diagram.drawio.svg)

### Integration Platform Capabilities

The integration platform supports the following patterns (from [Integration Architecture Spec](https://github.com/RideXpress/docs/blob/main/architecture/integration-architecture.md)):

| Pattern | Description | RideXpress Example |
|---------|-------------|--------------------|
| Synchronous Request-Reply | Real-time two-way communication | `GET /rides/{id}`, `GET /user` |
| Fire and Forget | Send a message without waiting for response | `POST /rides` → publishes to RabbitMQ |
| Message with Async Callback | Message sent, response handled independently | Ride status updates via push notifications |
| Messaging Publish-Subscribe | Distribute messages to multiple recipients | RabbitMQ topic for ride events → multiple consumers |
| Process Orchestration | Coordinate services into a cohesive workflow | Request Ride Process API orchestrating payment + driver assignment |
| Reliable Messaging | Zero tolerance for message loss | Payment confirmations, ride state transitions |

### Key Systems

| System | Description | Deployment | Integration |
|--------|-------------|------------|-------------|
| Salesforce | Customer management for sales and service | Cloud | MuleSoft Salesforce Connector |
| Google Maps | Geolocation and route optimization | Cloud | REST API via HTTP Connector |
| Okta | Authentication and user credential management | Cloud | REST API / OAuth 2.0 |
| Square | Payment processing for rides | Cloud | REST API via HTTP Connector |
| Gmail | Email notifications to users | Cloud | MuleSoft Gmail Connector |
| Apple Push Notifications | Push notifications to mobile devices | Cloud | REST API (HTTP/2) |
| PostgreSQL | Database for rides, users, and driver data | Cloud | MuleSoft Database Connector |
| RabbitMQ | Message broker for async processing | Cloud | MuleSoft AMQP Connector |

---

## Use Cases

> The following use cases are documented in the [RideXpress/docs Integration Catalog](https://github.com/RideXpress/docs/blob/main/architecture/integration-architecture/2-integration-catalog.md).
> Each use case maps to one or more Process APIs that orchestrate calls across System APIs.

### UC-1: User Sign Up

> **As a user**, I want the ability to sign up to the application using a Mobile App. The app will send a verification code to the registered email and/or phone.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/sign-up-user-use-case.drawio.svg) · [High-level flow](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/high-level-flows/sign-up-users-main-flows.drawio.svg)

**Timeliness**: Near real-time for initial response; email verification depends on the user.

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | User submits registration form from mobile app | Experience | `POST /user` on `mobile-experience-api` |
| 2 | Validate input and orchestrate sign-up | Process | `user-sign-up-process-api` |
| 3 | Create user record in database | System | `database-system-api` → `POST /users` |
| 4 | Create user in Okta for authentication | System | `okta-system-api` → `POST /users` |
| 5 | Send welcome email with verification code | System | `email-system-api` → `POST /send` |
| 6 | Return success/failure to mobile app | Experience | Response to caller |

**Implementation status**:
- [ ] Experience API `POST /user` flow connects to process API
- [ ] `user-sign-up-process-api` created and deployed
- [ ] `database-system-api` `POST /users` endpoint
- [ ] `okta-system-api` `POST /users` endpoint
- [ ] `email-system-api` `POST /send` endpoint

---

### UC-2: Request a Ride

> **As a customer**, I want the ability to select a destination in the Mobile App and the App will show the price based on criteria and also the estimated arrival time.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/request-ride-use-case.drawio.svg) · [Ride main flow](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/high-level-flows/ride-main-flow.drawio.svg) · [Square payment sequence](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/api-led/square-sequence.drawio.svg)

**Business trigger**: A new ride is requested by a customer.

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | Customer selects destination in mobile app | Experience | `POST /rides` on `mobile-experience-api` |
| 2 | Publish ride request to RabbitMQ for async processing | Experience | AMQP publish to `rides` queue |
| 3 | Consume ride request message | Process | `rides-process-async-api` → routes to `request-ride-process-api` |
| 4 | Calculate fare based on route distance | System | `google-maps-system-api` → `GET /directions` + `GET /distance` |
| 5 | Create ride record in database | System | `database-system-api` → `POST /rides` |
| 6 | Create payment link with Square | System | `square-system-api` → `POST /payment-link` |
| 7 | Find available driver near pickup location | System | `database-system-api` → query drivers by location |
| 8 | Broadcast ride request to nearby drivers | System | `push-notifications-system-api` → `POST /notify` |
| 9 | Return ride quote (price + ETA) to customer | Experience | Response to caller |

**Square payment flow** (from [Square API Design Doc](https://github.com/RideXpress/docs/blob/main/architecture/integration-architecture/system-apis/square.md)):
1. User requests ride → RideXpress orders a payment link from Square
2. User enters payment information → Square validates it
3. RideXpress requests the order using the order ID returned by Square
4. After the ride, RideXpress uses the Update Order endpoint to confirm or cancel payment

**Implementation status**:
- [ ] Experience API `POST /rides` publishes properly formatted message to RabbitMQ
- [ ] `rides-process-async-api` routes to `request-ride-process-api`
- [ ] `request-ride-process-api` created and deployed
- [ ] `google-maps-system-api` directions/distance endpoints
- [ ] `database-system-api` `POST /rides` endpoint
- [ ] `square-system-api` `POST /payment-link` endpoint
- [ ] `push-notifications-system-api` `POST /notify` endpoint

---

### UC-3: Accepting a Ride

> **As a driver**, I want the ability to accept or deny any inbound ride.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/accepting-ride-use-case.drawio.svg)

**Business trigger**: A ride is accepted by a driver.

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | Driver receives push notification with ride request | System | `push-notifications-system-api` |
| 2 | Driver accepts ride in mobile app | Experience | `PUT /rides/{id}/status` on `mobile-experience-api` |
| 3 | Orchestrate ride acceptance | Process | `accept-ride-process-api` |
| 4 | Update ride status to `ACCEPTED_BY_DRIVER` | System | `database-system-api` → `PATCH /ride/{id}` |
| 5 | Assign driver ID to ride record | System | `database-system-api` → `PATCH /ride/{id}` |
| 6 | Notify passenger that driver is assigned | System | `push-notifications-system-api` → `POST /notify` |
| 7 | Update ride status to `DRIVING_TO_PASSENGER_LOCATION` | System | `database-system-api` → `PATCH /ride/{id}` |

**Implementation status**:
- [ ] Experience API `PUT /rides/{id}/status` flow connects to process API
- [ ] `accept-ride-process-api` created and deployed
- [ ] `database-system-api` `PATCH /ride/{id}` endpoint
- [ ] `push-notifications-system-api` passenger notification

---

### UC-4: Wait for Ride

> **As a customer**, I want the ability to see the location of the driver to know when it will be near my pick up location.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/wait-for-ride-use-case.drawio.svg)

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | Driver app posts real-time location updates | Experience | `POST /user/geolocation` on `mobile-experience-api` |
| 2 | Store driver location | System | `database-system-api` → `POST /users/{driverId}/location` |
| 3 | Customer requests driver location | Experience | `GET /rides/{id}/driver/location` on `mobile-experience-api` |
| 4 | Retrieve driver's latest location + compute ETA | Process | `waiting-ride-process-api` |
| 5 | Get driver location from DB | System | `database-system-api` → `GET /users/{driverId}/location` |
| 6 | Calculate ETA to passenger pickup | System | `google-maps-system-api` → `GET /distance` |
| 7 | Driver arrives → update status to `WAITING_FOR_PASSANGER`\* | System | `database-system-api` → `PATCH /ride/{id}` |
| 8 | Notify passenger of driver arrival | System | `push-notifications-system-api` → `POST /notify` |
| 9 | Passenger gets in → status to `PASSENGER_GETS_INTO_THE_CAR` → `IN_ROUTE` | System | `database-system-api` → `PATCH /ride/{id}` |

**Implementation status**:
- [ ] Experience API `POST /user/geolocation` stores driver location
- [ ] Experience API `GET /rides/{id}/driver/location` returns location + ETA
- [ ] `waiting-ride-process-api` created and deployed
- [ ] `database-system-api` location endpoints
- [ ] `google-maps-system-api` distance endpoint

---

### UC-5: Finish Ride

> **As a driver**, I want the ability to finish the drive and **as a user**, I want the ability to confirm the end of the trip by scanning a QR code, using NFC, or some other method.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/finishing-ride-use-case.drawio.svg) · [Salesforce objects mapping](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/high-level-flows/initial-sf-objects-mapping-diagram.drawio.svg)

**Business trigger**: A ride is finished, and the payment must be confirmed.

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | Driver marks ride as arrived at destination | Experience | `PUT /rides/{id}/status` on `mobile-experience-api` |
| 2 | Orchestrate ride completion | Process | `finish-ride-process-api` |
| 3 | Update ride status to `ARRIVED_AT_DESTINATION` → `FINISHED` | System | `database-system-api` → `PATCH /ride/{id}` |
| 4 | Confirm payment with Square (update order fulfillment) | System | `square-system-api` → `PUT /orders/{orderId}` |
| 5 | Send ride summary to passenger via email | System | `email-system-api` → `POST /send` |
| 6 | Send ride summary push notification | System | `push-notifications-system-api` → `POST /notify` |
| 7 | Sync ride data to Salesforce for analytics | System | `salesforce-system-api` → `POST /rides` |
| 8 | Prompt passenger for feedback/rating | System | `push-notifications-system-api` → `POST /notify` |
| 9 | Passenger submits feedback | Experience | `POST /rides/{id}/feedback` on `mobile-experience-api` |
| 10 | Store feedback in database | System | `database-system-api` → `POST /ride/{id}/feedback` |

**Implementation status**:
- [ ] Experience API `PUT /rides/{id}/status` connects to `finish-ride-process-api`
- [ ] `finish-ride-process-api` created and deployed
- [ ] `square-system-api` `PUT /orders/{orderId}` endpoint
- [ ] `email-system-api` ride summary email
- [ ] `salesforce-system-api` ride data sync
- [ ] `database-system-api` feedback endpoint

---

### UC-6: User Login / Authentication

> **As a returning user** (client or driver), I want the ability to log in to the RideXpress mobile app so that I can access ride services without re-registering. The app should securely authenticate me via Okta, manage my session, and allow me to stay logged in across app restarts.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/user-login-authentication-use-case.drawio.svg)

**Timeliness**: Real-time — authentication must complete before the user can access any feature.

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | App checks for a valid cached session token | Experience | `GET /auth/session` on `mobile-experience-api` |
| 2 | Validate token or initiate login | Process | `user-sign-up-process-api` → `POST /auth/authenticate` |
| 3 | Validate credentials against Okta | System | `okta-system-api` → `POST /authn` |
| 4 | Return OAuth 2.0 access token + refresh token | Process | Response to Experience API |
| 5 | App stores tokens securely and redirects to main menu | Experience | Response to caller |

**Alternative flows**: Token refresh (`POST /auth/token/refresh`), password reset (`POST /auth/reset-password`), multi-device session invalidation.

**Edge conditions**: Refresh token expired → re-login; Okta unavailable → retry with backoff (3×); account suspended → error message; consecutive failure lockout (5 attempts / 15 min).

**Implementation status**:
- [ ] Experience API `POST /auth/login` flow connects to `user-sign-up-process-api`
- [ ] Experience API `POST /auth/token/refresh` flow refreshes Okta token
- [ ] Experience API `POST /auth/reset-password` flow triggers Okta password reset
- [ ] `user-sign-up-process-api` `POST /auth/authenticate` endpoint
- [ ] `okta-system-api` `POST /authn` endpoint
- [ ] `okta-system-api` `POST /token/refresh` endpoint
- [ ] `okta-system-api` `GET /users/{id}/session` endpoint
- [ ] `okta-system-api` `POST /users/{email}/reset-password` endpoint

---

### UC-7: Driver Sign Up / Onboarding

> **As a driver**, I want the ability to sign up on the RideXpress platform so that I can start accepting ride requests. The driver onboarding flow requires additional verification steps: vehicle registration, driver's license validation, insurance verification, background check initiation, and banking/payout setup.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/driver-sign-up-onboarding-use-case.drawio.svg)

**Timeliness**: Near real-time for registration steps; background check completion is asynchronous (hours to days).

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | Driver submits registration form (role = "driver") | Experience | `POST /user` on `mobile-experience-api` |
| 2 | Orchestrate driver sign-up (same process API, driver branch) | Process | `user-sign-up-process-api` → `POST /signup` |
| 3 | Create user record in database with `user_type = DRIVER` | System | `database-system-api` → `POST /users` |
| 4 | Create user in Okta with role = "driver" | System | `okta-system-api` → `POST /users` |
| 5 | Create Square customer profile for future payouts | System | `square-system-api` → `POST /customers` |
| 6 | Send email verification code | System | `email-system-api` → `POST /send` |
| 7 | Driver submits vehicle details | Experience | `POST /drivers/{id}/vehicle` on `mobile-experience-api` |
| 8 | Store vehicle in database | System | `database-system-api` → `POST /drivers/{id}/vehicles` |
| 9 | Driver uploads license and insurance documents | Experience | `POST /drivers/{id}/documents` on `mobile-experience-api` |
| 10 | Store documents and initiate background check (mocked) | System | `database-system-api` → `POST /drivers/{id}/documents`; `background-check-system-api` → `POST /checks` |
| 11 | Driver submits banking information | Experience | `POST /drivers/{id}/banking` on `mobile-experience-api` |
| 12 | Store banking info (tokenized) | System | `database-system-api` → `POST /drivers/{id}/banking` |
| 13 | Set onboarding status to `pending_verification` | System | `database-system-api` → `PATCH /drivers/{id}` |
| 14 | Notify driver of review outcome (async) | System | `push-notifications-system-api` → `POST /notify` + `email-system-api` → `POST /send` |

**Implementation status**:
- [ ] Experience API `POST /drivers/{id}/vehicle` endpoint
- [ ] Experience API `POST /drivers/{id}/documents` endpoint
- [ ] Experience API `POST /drivers/{id}/banking` endpoint
- [ ] `user-sign-up-process-api` driver-specific branch (vehicle, documents, banking, background check)
- [ ] `square-system-api` `POST /customers` endpoint
- [ ] `database-system-api` `POST/GET/PATCH /drivers/{id}` endpoints
- [ ] `database-system-api` `POST /drivers/{id}/vehicles` endpoint
- [ ] `database-system-api` `POST /drivers/{id}/documents` endpoint
- [ ] `database-system-api` `POST /drivers/{id}/banking` endpoint
- [ ] `background-check-system-api` `POST /checks` endpoint (mocked)
- [ ] `background-check-system-api` `GET /checks/{id}` endpoint (mocked)

---

### UC-8: Driver Availability (Go Online / Offline)

> **As a driver**, I want the ability to toggle my availability status to "Online" or "Offline" so that the system knows when I am available to accept ride requests.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/driver-availability-use-case.drawio.svg)

**Timeliness**: Real-time — availability change must propagate immediately to ride-matching queries.

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | Driver taps "Go Online" / "Go Offline" in the app | Experience | `PATCH /drivers/{id}/status` on `mobile-experience-api` |
| 2 | Orchestrate availability status change | Process | `driver-availability-process-api` → `PATCH /drivers/{id}/status` |
| 3 | Update driver status in database | System | `database-system-api` → `PATCH /drivers/{id}` |
| 4 | App begins/stops periodic location broadcast (every 10 s) | Experience | `POST /drivers/{id}/location` on `mobile-experience-api` |

**Stale location logic**: If no location update is received for 2 minutes → mark location as stale; for 10 minutes → auto-set driver offline.

**Edge conditions**: Cannot go offline during active ride (`IN_ROUTE`); cannot go online if account is `suspended` or `pending_verification`.

**Implementation status**:
- [ ] Experience API `PATCH /drivers/{id}/status` endpoint
- [ ] Experience API `POST /drivers/{id}/location` endpoint
- [ ] `driver-availability-process-api` created and deployed
- [ ] `driver-availability-process-api` `PATCH /drivers/{id}/status` endpoint
- [ ] `database-system-api` `PATCH /drivers/{id}` availability update
- [ ] Stale location detection logic (background check in `rides-process-async-api` or scheduler)

---

### UC-9: Ride Cancellation (Client & Driver)

> **As a client**, I want the ability to cancel a requested ride. **As a driver**, I want the ability to cancel an accepted ride. The system must enforce cancellation policies determining whether the client is charged or refunded, and handle ride reassignment when the driver cancels.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/ride-cancellation-use-case.drawio.svg)

**Timeliness**: Real-time — cancellation must update ride state and notify both parties immediately.

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | Client or driver taps "Cancel Ride" | Experience | `PATCH /rides/{id}/cancel` on `mobile-experience-api` |
| 2 | Orchestrate cancellation with charge/refund rules | Process | `cancel-ride-process-api` |
| 3 | Retrieve ride state and timestamps | System | `database-system-api` → `GET /rides/{id}` |
| 4a | **Cancel without charge**: Release payment hold | System | `square-system-api` → `PUT /orders/{orderId}` (state = CANCELED) |
| 4b | **Cancel with charge**: Commit payment | System | `square-system-api` → `POST /payments/{id}/commit` |
| 5 | Update ride status to `CANCELED_FOR_REFUND` or `CANCELED_WITHOUT_REFUND` | System | `database-system-api` → `PATCH /rides/{id}` |
| 6 | Notify both parties | System | `push-notifications-system-api` → `POST /notify` |
| 7 | **Driver cancellation only**: Trigger ride reassignment | Process | `request-ride-process-api` (re-search + notify new driver) |

**Cancellation rules** (from [ride-cancellation use case](https://github.com/RideXpress/docs/blob/main/architecture/use-cases/ride-cancellation.md)):
- Cancel **without charge**: ride in `NEW`/`WAITING_FOR_DRIVER`; driver ETA > 3 min in `DRIVING_TO_PASSENGER_LOCATION`; no driver confirmed after 2–3 min.
- Cancel **with charge**: driver arrives and passenger does not board within 5 min; client cancels when driver is < 3 min away; OTP mismatch.

**Implementation status**:
- [ ] Experience API `PATCH /rides/{id}/cancel` endpoint
- [ ] `cancel-ride-process-api` created and deployed
- [ ] Charge vs. no-charge decision logic (state + timestamps + ETA)
- [ ] `square-system-api` `POST /payments/{id}/commit` endpoint
- [ ] `database-system-api` cancellation state updates
- [ ] Ride reassignment flow (driver cancellation → re-run request-ride)

---

### UC-10: Ride Pricing / Fare Estimation

> **As a client**, I want to see the estimated price of a ride before confirming the request, with a breakdown by ride type (Economy, Comfort, Premium), so that I can make an informed decision.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/ride-pricing-use-case.drawio.svg)

**Timeliness**: Near real-time — estimate must return within 2 seconds.

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | Client enters pickup and destination | Experience | `POST /rides/estimate` on `mobile-experience-api` |
| 2 | Calculate route distance and duration | System | `google-maps-system-api` → `POST /geolocation` |
| 3 | Retrieve pricing parameters | System | `database-system-api` → `GET /pricing` |
| 4 | Check surge pricing for pickup zone | System | `database-system-api` → `GET /pricing/surge?zone={zone_id}` |
| 5 | Calculate fare for each ride type and apply surge multiplier | Process | `request-ride-process-api` → `POST /pricing/calculate` |
| 6 | Return fare estimate per ride type with breakdown | Experience | Response to caller |

**Fare formula**: `estimated_total = max(base_fare + (distance × per_mile_rate) + (duration × per_minute_rate), minimum_fare) × ride_type_multiplier × surge_multiplier + booking_fee`

**Fare lock**: Estimate is locked for 5 minutes; client must re-estimate if it expires.

**Implementation status**:
- [ ] Experience API `POST /rides/estimate` endpoint
- [ ] `request-ride-process-api` `POST /pricing/calculate` endpoint
- [ ] `database-system-api` `GET /pricing` endpoint (base pricing parameters)
- [ ] `database-system-api` `GET /pricing/surge` endpoint (zone-based surge query)
- [ ] `database-system-api` `GET /ride-types` endpoint
- [ ] Surge multiplier calculation logic (demand/supply ratio per zone)
- [ ] Ride type multiplier stacking with surge

---

### UC-11: Ride Type Selection

> **As a client**, I want the ability to choose between different ride types (Economy, Comfort, Premium) so I can select the option that best fits my needs and budget.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/ride-type-selection-use-case.drawio.svg)

**Timeliness**: Handled within the fare estimation response (UC-10) — no additional round-trip required.

| Ride Type | Pricing Multiplier | Vehicle Requirements |
|-----------|-------------------|----------------------|
| Economy | 1.0× | Any approved vehicle |
| Comfort | 1.3× | Year ≥ 2020, sedan or larger |
| Premium | 2.0× | Year ≥ 2022, luxury brands only |

**Integration**: Ride type is passed as a field in `POST /rides` (Experience API) and stored in the `rides` table. `database-system-api` `GET /drivers` is filtered by `?type={type}` to match eligible drivers.

**Implementation status**:
- [ ] `ride_type` field added to `rides` table in DB schema and RAML spec
- [ ] `ride_types` table in DB (Economy/Comfort/Premium config with multipliers)
- [ ] `database-system-api` `GET /ride-types` endpoint
- [ ] `database-system-api` `GET /drivers?type={type}` filter
- [ ] `request-ride-process-api` applies ride type multiplier in fare calculation

---

### UC-12: Real-time In-Ride Tracking

> **As a client**, I want the ability to track the progress of my ride on a map in real-time during the trip (while "In route") so I can see the route, ETA at my destination, and share my trip with trusted contacts.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/real-time-ride-tracking-use-case.drawio.svg)

**Timeliness**: Near real-time via HTTP polling — driver location updated every 10 s, client polls every 5 s (MVP).

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | Driver broadcasts GPS coordinates every 10 s | Experience | `POST /drivers/{id}/location` on `mobile-experience-api` |
| 2 | Client polls for live location every 5 s | Experience | `GET /rides/{id}/live-location` on `mobile-experience-api` |
| 3 | Recalculate ETA at destination | System | `google-maps-system-api` → `GET /routes/{ride_id}/eta` |
| 4 | Client generates a shareable trip link | Experience | `POST /rides/{id}/share` on `mobile-experience-api` |
| 5 | Third party views live ride (read-only) | Experience | `GET /rides/{id}/shared-view` on `mobile-experience-api` |

**Edge conditions**: GPS signal lost → show last known position; route deviation > 1 km → alert client; shared link expires on ride completion.

**Implementation status**:
- [ ] Experience API `GET /rides/{id}/live-location` endpoint
- [ ] Experience API `POST /rides/{id}/share` endpoint
- [ ] Experience API `GET /rides/{id}/shared-view` endpoint (public, no auth)
- [ ] `database-system-api` latest driver location query for a ride
- [ ] Route deviation detection logic (in `waiting-ride-process-api` or `finish-ride-process-api`)

---

### UC-13: Payment Failure Handling

> **As the system**, I need to handle payment failures at every stage of the ride lifecycle — payment hold creation, payment commit (charge), and refund processing — so that money is never silently lost.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/payment-failure-handling-use-case.drawio.svg)

**Timeliness**: Synchronous retries are immediate; async recovery jobs run every 15 minutes.

| Stage | Failure Scenario | Recovery Mechanism |
|-------|------------------|--------------------|
| Payment hold (ride request) | Square error / card declined | Retry 3× with exponential backoff (1 s, 2 s, 4 s); notify client; do not create ride |
| Payment commit (finish ride) | Square error | Retry 3× with backoff; mark ride `FINISHED` regardless; queue in `pending_collection` |
| Pending collection | Commit retries exhausted | Background job in `rides-process-async-api` retries every 15 min for up to 24 h |
| Payment hold expired | Hold > 7 days | Create new charge instead of committing hold; if that fails → flag `uncollected` |
| Refund (cancellation) | Square error | Retry 3×; queue in `pending_refund`; background job retries every 15 min for up to 48 h |
| Tip causes over-hold | Final amount > hold | Create supplemental charge; if fails → queue supplemental amount in `pending_collection` |

**Implementation status**:
- [ ] `square-system-api` `POST /payments/{id}/commit` endpoint
- [ ] Retry logic (3× exponential backoff) on all Square calls in process APIs
- [ ] `pending_collection` and `pending_refund` status values in `payments` table
- [ ] Background retry scheduler in `rides-process-async-api` (every 15 min)
- [ ] `database-system-api` endpoints for pending payment queues
- [ ] Alert/notification for `uncollected` or permanently failed payments

---

### UC-14: Driver Payout / Earnings

> **As a driver**, I want the ability to view my earnings from completed rides and receive payouts to my bank account on a regular weekly schedule.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/driver-payout-earnings-use-case.drawio.svg)

**Timeliness**: Earnings are recorded synchronously at ride completion; payout disbursement runs weekly (Monday 00:00 UTC) via a scheduler in `rides-process-async-api`.

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | Ride is completed; `finish-ride-process-api` calculates driver earnings | Process | `finish-ride-process-api` |
| 2 | Create earnings record | System | `database-system-api` → `POST /drivers/{id}/earnings` |
| 3 | Weekly scheduler fires | Async | `rides-process-async-api` Scheduler source |
| 4 | Query drivers with positive balance ≥ $10.00 | System | `database-system-api` → `GET /drivers/payouts/pending` |
| 5 | Initiate bank transfer for each eligible driver | System | `square-system-api` → `POST /payouts` |
| 6 | Store payout record with status = "processing" | System | `database-system-api` → `POST /drivers/{id}/payouts` |
| 7 | Poll / receive Square confirmation; update status to "completed" | System | `square-system-api` → `GET /payouts/{id}` |
| 8 | Notify driver of payout | System | `push-notifications-system-api` → `POST /notify` |

**Earnings formula**: `net_earnings = (gross_fare × 0.75) + tip + cancellation_portion - deductions`

**Edge conditions**: Payout < $10.00 threshold → roll over; banking info invalid → mark `failed`, notify driver; earnings dispute → routed to support (UC-16).

**Implementation status**:
- [ ] `driver_earnings` table in DB schema
- [ ] `driver_payouts` table in DB schema
- [ ] `finish-ride-process-api` earnings calculation and `POST /drivers/{id}/earnings` call
- [ ] Weekly Scheduler flow in `rides-process-async-api`
- [ ] `database-system-api` `GET /drivers/payouts/pending` endpoint
- [ ] `database-system-api` `POST /drivers/{id}/payouts` endpoint
- [ ] `database-system-api` `GET /drivers/{id}/earnings` endpoint (for in-app display)
- [ ] `square-system-api` `POST /payouts` endpoint
- [ ] `square-system-api` `GET /payouts/{id}` endpoint (status polling)
- [ ] Payout failure handling (retry + notify driver)

---

### UC-15: Ride History & Receipts

> **As a user** (client or driver), I want the ability to view my past rides, see trip details, and access receipt information so I can track my ride history and expenses.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/ride-history-receipts-use-case.drawio.svg)

**Timeliness**: On-demand retrieval — paginated read from database.

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | User navigates to "Ride History" | Experience | `GET /users/{id}/rides?page=1&size=20` on `mobile-experience-api` |
| 2 | Retrieve paginated rides from DB | System | `database-system-api` → `GET /rides?user_id={id}` |
| 3 | User taps on a ride for details | Experience | `GET /rides/{id}/details` on `mobile-experience-api` |
| 4 | Retrieve ride details + route | System | `database-system-api` → `GET /rides/{id}`; `google-maps-system-api` → `GET /routes/{ride_id}` |
| 5 | User requests receipt (JSON) | Experience | `GET /rides/{id}/receipt` on `mobile-experience-api` |
| 6 | Aggregate receipt data | System | `database-system-api` → `GET /rides/{id}` + `GET /payments/{ride_id}` |

**Receipt content** (JSON, rendered on client): ride date/time/route, itemized fare breakdown, payment method (last 4 digits), total charged, ride ID.

**Implementation status**:
- [ ] Experience API `GET /users/{id}/rides` endpoint (paginated ride history)
- [ ] Experience API `GET /rides/{id}/details` endpoint
- [ ] Experience API `GET /rides/{id}/receipt` endpoint (JSON)
- [ ] `database-system-api` `GET /rides?user_id={id}` endpoint (paginated)
- [ ] `database-system-api` `GET /payments/{ride_id}` endpoint
- [ ] `google-maps-system-api` `GET /routes/{ride_id}` endpoint

---

### UC-16: Help / Support / Dispute Resolution

> **As a user** (client or driver), I want the ability to access in-app support, report safety issues, and dispute charges so that my concerns are addressed promptly.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/help-support-dispute-use-case.drawio.svg)

**Timeliness**: Near real-time for ticket creation; resolution depends on SLA (Urgent: 4 h, High: 24 h, Medium: 72 h, Low: 5 days).

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | User selects support category and submits request | Experience | `POST /support/tickets` on `mobile-experience-api` |
| 2 | Create Salesforce Case | System | `salesforce-system-api` → `POST /cases` |
| 3 | **Fare dispute**: Support reviews ride; if valid → issue refund | System | `square-system-api` → partial/full refund |
| 4 | **Safety report**: Escalate immediately, possibly suspend account | System | `salesforce-system-api` → `PATCH /contacts/{id}` |

**Implementation status**:
- [ ] Experience API `POST /support/tickets` endpoint
- [ ] `salesforce-system-api` `POST /cases` endpoint
- [ ] `salesforce-system-api` `PATCH /contacts/{id}` endpoint (account suspension)
- [ ] Partial refund flow in `square-system-api`
- [ ] Duplicate ticket detection logic

---

### UC-17: User Profile Management

> **As a user** (client or driver), I want the ability to view and update my personal profile information so that my account stays current. Drivers additionally manage vehicle information and banking details.

📐 [Use case diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/user-profile-management-use-case.drawio.svg)

| Step | Action | API Layer | API / System |
|------|--------|-----------|--------------|
| 1 | User retrieves current profile | Experience | `GET /users/{id}/profile` on `mobile-experience-api` |
| 2 | User submits updated fields | Experience | `PATCH /users/{id}/profile` on `mobile-experience-api` |
| 3 | Sync email/name changes to Okta | System | `okta-system-api` → `PATCH /users/{id}` |
| 4 | Sync profile changes to Square | System | `square-system-api` → `PATCH /customers/{id}` |
| 5 | Persist changes to database | System | `database-system-api` → `PATCH /users/{id}` |

**Driver-only**: Vehicle changes trigger document re-verification; banking info changes take effect in the next payout cycle.

**Implementation status**:
- [ ] Experience API `GET /users/{id}/profile` endpoint
- [ ] Experience API `PATCH /users/{id}/profile` endpoint
- [ ] `okta-system-api` `PATCH /users/{id}` endpoint
- [ ] `square-system-api` `PATCH /customers/{id}` endpoint
- [ ] Email/phone change re-verification flow (via `email-system-api` / `okta-system-api`)

---

> 📐 [Ride states diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/use-cases/ride-states.drawio.svg)

The following states govern the ride lifecycle (from `ride-data-type.raml`):

```
                              ┌──────────────────────────────┐
                              │            NEW               │
                              └──────────┬───────────────────┘
                                         │ POST /rides
                              ┌──────────▼───────────────────┐
                              │    WAITING_FOR_DRIVER         │
                              └──────────┬───────────────────┘
                                         │ Driver accepts
                              ┌──────────▼───────────────────┐
                              │    ACCEPTED_BY_DRIVER         │
                              └──────────┬───────────────────┘
                                         │
                              ┌──────────▼───────────────────┐
                              │ DRIVING_TO_PASSENGER_LOCATION │
                              └──────────┬───────────────────┘
                                         │ Driver arrives
                              ┌──────────▼───────────────────┐
                              │   WAITING_FOR_PASSANGER  (*)  │
                              └──────────┬───────────────────┘
                                         │ Passenger gets in
                              ┌──────────▼───────────────────┐
                              │ PASSENGER_GETS_INTO_THE_CAR   │
                              └──────────┬───────────────────┘
                                         │
                              ┌──────────▼───────────────────┐
                              │        IN_ROUTE              │
                              └──────────┬───────────────────┘
                                         │ Arrived
                              ┌──────────▼───────────────────┐
                              │  ARRIVED_AT_DESTINATION       │
                              └──────────┬───────────────────┘
                                         │ Payment confirmed
                              ┌──────────▼───────────────────┐
                              │        FINISHED              │
                              └──────────────────────────────┘

  Cancel paths (from WAITING_FOR_DRIVER, ACCEPTED_BY_DRIVER, WAITING_FOR_PASSANGER):
    ├── CANCELED_FOR_REFUND
    └── CANCELED_WITHOUT_REFUND

  (*) Known typo from RAML spec — should be WAITING_FOR_PASSENGER
```

---

## API Application Catalog

> From the [Integration Architecture — API Application Catalogue](https://github.com/RideXpress/docs/blob/main/architecture/integration-architecture/3-mulesoft-integration-implementation.md#api-application-catalogue)

| API Name | Type | Maven Artifact ID | CloudHub Domain | Function |
|----------|------|-------------------|-----------------|----------|
| `mobile-experience-api` | Experience | `mobile-experience-api` | `ridexpress-{env}-mobile` | Entry point for mobile app — drivers and passengers |
| `user-sign-up-process-api` | Process | `user-sign-up-process-api` | `ridexpress-{env}-user-sign-up` | Orchestrates user registration, driver onboarding, and authentication across systems |
| `request-ride-process-api` | Process | `request-ride-process-api` | `ridexpress-{env}-request-ride` | Orchestrates ride request, fare calculation, driver matching |
| `accept-ride-process-api` | Process | `accept-ride-process-api` | `ridexpress-{env}-accept-ride` | Orchestrates ride acceptance by driver |
| `waiting-ride-process-api` | Process | `waiting-ride-process-api` | `ridexpress-{env}-wait-for-ride` | Orchestrates waiting/tracking phase |
| `finish-ride-process-api` | Process | `finish-ride-process-api` | `ridexpress-{env}-finish-ride` | Orchestrates ride completion, payment, feedback |
| `cancel-ride-process-api` | Process | `cancel-ride-process-api` | `ridexpress-{env}-cancel-ride` | Orchestrates ride cancellation, charge/refund rules, and driver reassignment |
| `driver-availability-process-api` | Process | `driver-availability-process-api` | `ridexpress-{env}-driver-availability` | Manages driver online/offline status and stale location detection |
| `okta-system-api` | System | `okta-system-api` | `ridexpress-{env}-okta` | CRUD for users + authentication/OAuth support |
| `square-system-api` | System | `square-system-api` | `ridexpress-{env}-square` | Payment links, orders, refunds, payouts via Square |
| `salesforce-system-api` | System | `salesforce-system-api` | `ridexpress-{env}-salesforce` | CRUD on Salesforce entities for analytics and support cases |
| `google-maps-system-api` | System | `google-maps-system-api` | `ridexpress-{env}-google-maps` | Geolocation, route optimization, ETA |
| `database-system-api` | System | `database-system-api` | `ridexpress-{env}-db` | CRUD for non-sensitive data in PostgreSQL |
| `push-notifications-system-api` | System | `push-notifications-system-api` | `ridexpress-{env}-push-notifications` | Push notifications to drivers and passengers |
| `email-system-api` | System | `email-system-api` | `ridexpress-{env}-email` | Email sending (welcome, receipts, verifications) |
| `background-check-system-api` | System | `background-check-system-api` | `ridexpress-{env}-background-check` | Driver background check initiation and status retrieval (mocked 3rd-party integration) |

> **Note**: The existing `ridexpress-experience-api` project maps to `mobile-experience-api` in the docs catalog.
> The existing `rides-process-async-api` is a supporting async consumer that routes messages to the appropriate Process APIs, and also hosts the weekly driver payout scheduler.

---

## Repository Structure

> **Monorepo strategy**: All MuleSoft-related code lives in a single repository. One System API per system of record, one Process API per use case, one Experience API per consumer platform. See [SDLC docs](https://github.com/RideXpress/docs/blob/main/architecture/anypoint-platform-architecture/software-development-lifecycle.md).

```
mulesoft/                              # Monorepo root
├── IMPLEMENTATION_PLAN.md             # This file — track progress here
├── README.md                          # Project overview
├── design-center/                     # RAML API specs (synced with Anypoint Design Center)
│   ├── ridexpress-experience-api/     # Experience API spec
│   ├── db-system-api/                 # Database System API spec
│   ├── request-ride-process-api/      # Request Ride Process API spec
│   ├── square-system-api/             # Square System API spec
│   ├── okta-system-api/               # Okta System API spec (stub)
│   ├── google-maps-system-api/        # Google Maps System API spec (stub)
│   ├── salesforce-system-api/         # Salesforce System API spec (stub)
│   ├── email-system-api/              # Gmail System API spec (stub)
│   ├── apple-push-notifications.../   # Apple Push Notifications spec (stub)
│   ├── common-data-types-library/     # Shared data types (apiResponse, location, paymentStatus, etc.)
│   ├── user-data-type/                # User data type definition
│   ├── ride-data-type/                # Ride data type definition
│   ├── square/                        # Square data types and examples
│   └── ...                            # Traits, security schemes, resource types
├── ridexpress-experience-api/         # ✅ Experience API implementation (= mobile-experience-api)
├── rides-process-async-api/           # ✅ Async ride processing (RabbitMQ consumer) + payout scheduler
├── database-system-api/               # 🔲 To be created — Database System API
├── user-sign-up-process-api/          # 🔲 To be created — User Sign Up, Driver Onboarding & Auth Process API
├── request-ride-process-api/          # 🔲 To be created — Request Ride Process API
├── accept-ride-process-api/           # 🔲 To be created — Accept Ride Process API
├── waiting-ride-process-api/          # 🔲 To be created — Waiting Ride Process API
├── finish-ride-process-api/           # 🔲 To be created — Finish Ride Process API
├── cancel-ride-process-api/           # 🔲 To be created — Cancel Ride Process API
├── driver-availability-process-api/   # 🔲 To be created — Driver Availability Process API
├── okta-system-api/                   # 🔲 To be created — Okta integration
├── google-maps-system-api/            # 🔲 To be created — Google Maps integration
├── square-system-api/                 # 🔲 To be created — Square payments integration
├── salesforce-system-api/             # 🔲 To be created — Salesforce CRM integration
├── email-system-api/                  # 🔲 To be created — Email notification integration
├── push-notifications-system-api/     # 🔲 To be created — Push notifications (APNs)
├── background-check-system-api/       # 🔲 To be created — Background check (mocked 3rd-party)
└── util/                              # Maven settings & utility files
```

### Mule Project File Structure Convention

> From [API Implementation Template](https://github.com/RideXpress/docs/blob/main/architecture/anypoint-platform-architecture/common-services.md#api-implementation-template)

Each Mule project should follow this standard file structure:

```
{project-name}/
├── pom.xml                                    # Maven POM (with parent POM reference)
├── mule-artifact.json                         # Mule artifact descriptor
├── exchange-docs/
│   └── home.md                                # Exchange documentation
├── src/
│   ├── main/
│   │   ├── mule/
│   │   │   ├── {artifact-name}.xml            # API interface — auto-generated flows (APIKit)
│   │   │   ├── implementation.xml             # Implementation flows (or folder for multiple files)
│   │   │   ├── common.xml                     # Project configs: DB connections, JMS, HTTP request, autodiscovery
│   │   │   └── errors.xml                     # Error handling strategies
│   │   └── resources/
│   │       ├── api/                           # RAML spec (synced from Design Center)
│   │       │   └── {api-name}.raml
│   │       ├── config.yaml                    # Common configuration properties
│   │       ├── dwl/                           # DataWeave transformation files
│   │       │   ├── {method}-{resource}-request.dwl
│   │       │   └── {method}-{resource}-response.dwl
│   │       ├── log4j2.xml                     # Logging configuration
│   │       └── application-types.xml          # Application type definitions (if applicable)
│   └── test/
│       ├── munit/                             # MUnit test suites
│       └── resources/
│           └── log4j2-test.xml                # Test logging configuration
```

---

## Phase 1 — Experience API (`ridexpress-experience-api`)

> The Experience API is the entry point for the mobile app. It routes requests to Process and System APIs.
> All flow stubs (APIKit routing) are already scaffolded. The remaining work is to add actual business logic
> that calls downstream Process/System APIs via HTTP requests or AMQP messages.

### 1.1 User Endpoints (`/user`, `/users`, `/auth`)

| # | Endpoint | Flow Name | Status | Notes |
|---|----------|-----------|--------|-------|
| 1 | `POST /user` | `post:\user:router` | 🔲 Stub only | Call **user-sign-up-process-api** → orchestrates DB insert + Okta user creation + welcome email |
| 2 | `GET /user` | `get:\user:router` | 🟡 Partial | Calls `get-user-by-id-impl` sub-flow (direct DB query). Should call **database-system-api** instead |
| 3 | `PUT /user` | `put:\user:router` | 🔲 Stub only | Call **database-system-api** `PATCH /users/{id}` to update user record |
| 4 | `DELETE /user` | `delete:\user:router` | 🔲 Stub only | Call **database-system-api** to soft-delete (deactivate) user |
| 5 | `GET /user/vehicles` | `get:\user\vehicles:router` | 🔲 Stub only | Call **database-system-api** to retrieve driver's vehicles |
| 6 | `PUT /user/vehicles/{id}` | `put:\user\vehicles\(id):router` | 🔲 Stub only | Call **database-system-api** to update active vehicle |
| 7 | `POST /user/geolocation` | `post:\user\geolocation:router` | 🔲 Stub only | Call **database-system-api** `POST /users/{id}/location` to post real-time location |
| 8 | `POST /user/attachments` | `post:\user\attachments:router` | 🔲 Stub only | Store file (S3/object storage) — may need a new system API or direct connector |
| 9 | `GET /users/{id}/profile` | `get:\users\(id)\profile:router` | 🔲 To add | UC-17: retrieve user profile |
| 10 | `PATCH /users/{id}/profile` | `patch:\users\(id)\profile:router` | 🔲 To add | UC-17: update profile; sync to Okta + Square |
| 11 | `GET /users/{id}/rides` | `get:\users\(id)\rides:router` | 🔲 To add | UC-15: paginated ride history (`?page=&size=`) |
| 12 | `POST /auth/login` | `post:\auth\login:router` | 🔲 To add | UC-6: login → **user-sign-up-process-api** `POST /auth/authenticate` |
| 13 | `POST /auth/token/refresh` | `post:\auth\token\refresh:router` | 🔲 To add | UC-6: refresh Okta access token |
| 14 | `POST /auth/reset-password` | `post:\auth\reset-password:router` | 🔲 To add | UC-6: trigger Okta password reset email |

### 1.2 Rides Endpoints (`/rides`)

| # | Endpoint | Flow Name | Status | Notes |
|---|----------|-----------|--------|-------|
| 9 | `GET /rides` | `get:\rides:router` | 🟡 Partial | Calls `get-rides-impl` sub-flow (direct DB query). Should call **database-system-api** instead |
| 10 | `POST /rides` | `post:\rides:router` | 🟡 Partial | Publishes to RabbitMQ. Should include DataWeave transformation and call **request-ride-process-api** |
| 11 | `POST /rides/estimate` | `post:\rides\estimate:router` | 🔲 To add | UC-10/11: fare estimate per ride type → **request-ride-process-api** `POST /pricing/calculate` |
| 12 | `GET /rides/{id}` | `get:\rides\(id):router` | 🔲 Stub only | Call **database-system-api** `GET /rides/{id}` |
| 13 | `GET /rides/{id}/details` | `get:\rides\(id)\details:router` | 🔲 To add | UC-15: ride details + route (DB + Google Maps) |
| 14 | `GET /rides/{id}/receipt` | `get:\rides\(id)\receipt:router` | 🔲 To add | UC-15: JSON receipt (DB ride + payment data) |
| 15 | `GET /rides/{id}/passenger` | `get:\rides\(id)\passenger:router` | 🔲 Stub only | Call **database-system-api** to get passenger details for ride |
| 16 | `GET /rides/{id}/passenger/location` | `get:\rides\(id)\passenger\location:router` | 🔲 Stub only | Call **database-system-api** `GET /users/{passengerId}/location` |
| 17 | `GET /rides/{id}/driver` | `get:\rides\(id)\driver:router` | 🔲 Stub only | Call **database-system-api** to get driver details for ride |
| 18 | `GET /rides/{id}/driver/location` | `get:\rides\(id)\driver\location:router` | 🔲 Stub only | Call **database-system-api** `GET /users/{driverId}/location` + compute arrival time |
| 19 | `GET /rides/{id}/live-location` | `get:\rides\(id)\live-location:router` | 🔲 To add | UC-12: latest driver location for in-ride tracking (HTTP polling) |
| 20 | `POST /rides/{id}/share` | `post:\rides\(id)\share:router` | 🔲 To add | UC-12: generate shareable trip link |
| 21 | `GET /rides/{id}/shared-view` | `get:\rides\(id)\shared-view:router` | 🔲 To add | UC-12: public (no-auth) shared trip view |
| 22 | `GET /rides/{id}/payment` | `get:\rides\(id)\payment:router` | 🔲 Stub only | Call **square-system-api** to retrieve payment status |
| 23 | `GET /rides/{id}/route` | `get:\rides\(id)\route:router` | 🔲 Stub only | Call **google-maps-system-api** for route details |
| 24 | `POST /rides/{id}/feedback` | `post:\rides\(id)\feedback:router` | 🟡 Partial | Publishes to RabbitMQ. Should transform payload and include ride ID |
| 25 | `GET /rides/{id}/status` | `get:\rides\(id)\status:router` | 🔲 Stub only | Call **database-system-api** `GET /rides/{id}` and extract status + arrival time |
| 26 | `PUT /rides/{id}/status` | `put:\rides\(id)\status:router` | 🔲 Stub only | Call **database-system-api** `PATCH /rides/{id}` to update status |
| 27 | `PATCH /rides/{id}/cancel` | `patch:\rides\(id)\cancel:router` | 🔲 To add | UC-9: cancel ride → **cancel-ride-process-api** |
| 28 | `GET /rides/{id}/summary` | `get:\rides\(id)\summary:router` | 🔲 Stub only | Aggregate data: ride details + passenger info + driver info + route from multiple APIs |

### 1.3 Drivers Endpoints (`/drivers`)

| # | Endpoint | Flow Name | Status | Notes |
|---|----------|-----------|--------|-------|
| 29 | `PATCH /drivers/{id}/status` | `patch:\drivers\(id)\status:router` | 🔲 To add | UC-8: driver go online/offline → **driver-availability-process-api** |
| 30 | `POST /drivers/{id}/location` | `post:\drivers\(id)\location:router` | 🔲 To add | UC-8/12: driver broadcasts GPS location → **database-system-api** |
| 31 | `POST /drivers/{id}/vehicle` | `post:\drivers\(id)\vehicle:router` | 🔲 To add | UC-7: driver vehicle registration → **user-sign-up-process-api** |
| 32 | `POST /drivers/{id}/documents` | `post:\drivers\(id)\documents:router` | 🔲 To add | UC-7: driver license/insurance upload → **user-sign-up-process-api** |
| 33 | `POST /drivers/{id}/banking` | `post:\drivers\(id)\banking:router` | 🔲 To add | UC-7: driver banking info → **user-sign-up-process-api** |

### 1.4 Geolocations Endpoints (`/geolocations`)

| # | Endpoint | Flow Name | Status | Notes |
|---|----------|-----------|--------|-------|
| 34 | `GET /geolocations` | `get:\geolocations:router` | 🔲 Stub only | Call **google-maps-system-api** for location search |
| 35 | `GET /geolocations/{id}` | `get:\geolocations\(id):router` | 🔲 Stub only | Call **google-maps-system-api** for place details |

### 1.5 Support Endpoints (`/support`)

| # | Endpoint | Flow Name | Status | Notes |
|---|----------|-----------|--------|-------|
| 36 | `POST /support/tickets` | `post:\support\tickets:router` | 🔲 To add | UC-16: create support ticket → **salesforce-system-api** `POST /cases` |

### 1.6 Experience API — Infrastructure Improvements

- [ ] **Error handling**: Add `on-error-continue` / `on-error-propagate` in each flow for downstream call failures
- [ ] **HTTP request configurations**: Configure `google-maps`, `okta`, `square` request-configs with proper basePath, host, port properties
- [ ] **DataWeave transformations**: Transform between Experience API data model and downstream API data models
- [ ] **Correlation ID / X-Transaction-Id**: Propagate the `X-Transaction-Id` header to all downstream calls
- [ ] **OAuth token validation**: Implement token introspection via Okta before processing requests
- [ ] **Response mapping**: Map downstream API responses to the RAML-defined response schemas

### 1.7 Experience API — Direct DB Access Refactoring

> **Current issue**: The Experience API has direct database access via `db-operations-impl.xml` with PostgreSQL queries.
> Per API-led connectivity best practices, the Experience layer should NOT directly access databases.
> These should be refactored to call the **database-system-api** via HTTP instead.

- [ ] Refactor `get-rides-impl` sub-flow to call `database-system-api` HTTP endpoint instead of direct DB query
- [ ] Refactor `get-user-by-id-impl` sub-flow to call `database-system-api` HTTP endpoint instead of direct DB query
- [ ] Remove PostgreSQL dependency from Experience API `pom.xml` after refactoring
- [ ] Remove `db:config` from Experience API `config.xml` after refactoring

---

## Phase 2 — Database System API (`database-system-api`)

> The Database System API encapsulates all PostgreSQL operations. It is the single point of access for
> the database and provides a clean REST API over the RideXpress database schema.
> Per the [API Application Catalogue](https://github.com/RideXpress/docs/blob/main/architecture/integration-architecture/3-mulesoft-integration-implementation.md#api-application-catalogue),
> this API "provides the CRUD operations to store non-sensitive information in the database."

### 2.1 Project Setup

- [x] Create Mule 4 project `database-system-api/` with standard structure
- [x] Add `pom.xml` with dependencies: HTTP Connector, DB Connector, APIKit, PostgreSQL driver
- [x] Add `config.xml` with HTTP listener, APIKit router, and PostgreSQL connection config
- [x] Add `config.properties` with externalized database connection properties
- [x] Add RAML spec from `design-center/db-system-api/db-system-api.raml`
- [x] Add `mule-artifact.json`
- [x] Add `log4j2.xml` configuration

### 2.2 User Endpoints

| # | Endpoint | Status | DB Operation |
|---|----------|--------|--------------|
| 1 | `POST /users` | ✅ Implemented | `INSERT INTO ridexpress.users (...)` |
| 2 | `GET /users` | ✅ Implemented | `SELECT * FROM ridexpress.users` |
| 3 | `GET /users/{id}` | ✅ Implemented | `SELECT * FROM ridexpress.users WHERE user_id = :id` |
| 4 | `PATCH /users/{id}` | ✅ Implemented | `UPDATE ridexpress.users SET ... WHERE user_id = :id` |
| 5 | `GET /users/{id}/location` | ✅ Implemented | `SELECT * FROM ridexpress.user_locations WHERE user_id = :id ORDER BY created_at DESC LIMIT 1` |
| 6 | `POST /users/{id}/location` | ✅ Implemented | `INSERT INTO ridexpress.user_locations (...)` |
| 7 | `POST /users/{id}/feedback` | ✅ Implemented | `INSERT INTO ridexpress.user_feedback (...)` |

### 2.3 Ride Endpoints

| # | Endpoint | Status | DB Operation |
|---|----------|--------|--------------|
| 8 | `POST /rides` | ✅ Implemented | `INSERT INTO ridexpress.rides (...)` |
| 9 | `GET /ride/{id}` | ✅ Implemented | `SELECT * FROM ridexpress.rides WHERE ride_id = :id` |
| 10 | `PATCH /ride/{id}` | ✅ Implemented | `UPDATE ridexpress.rides SET ... WHERE ride_id = :id` |
| 11 | `POST /ride/{id}/feedback` | ✅ Implemented | `INSERT INTO ridexpress.ride_feedback (...)` |

### 2.4 Vehicle Endpoints

| # | Endpoint | Status | DB Operation |
|---|----------|--------|--------------|
| 12 | `GET /users/{id}/vehicles` | ✅ Implemented | `SELECT * FROM ridexpress.vehicles WHERE user_id = :id` |
| 13 | `POST /users/{id}/vehicles` | ✅ Implemented | `INSERT INTO ridexpress.vehicles (...)` |
| 14 | `PUT /users/{id}/vehicles/{vehicleId}` | ✅ Implemented | `UPDATE ridexpress.vehicles SET ... WHERE vehicle_id = :vehicleId` |

### 2.5 Driver Endpoints

| # | Endpoint | Status | DB Operation |
|---|----------|--------|--------------|
| 15 | `GET /drivers/{id}` | ✅ Implemented | `SELECT * FROM ridexpress.drivers WHERE user_id = :id` |
| 16 | `POST /drivers/{id}` | ✅ Implemented | `INSERT INTO ridexpress.drivers (...)` |
| 17 | `PATCH /drivers/{id}` | ✅ Implemented | `UPDATE ridexpress.drivers SET ... WHERE user_id = :id` (status, availability) |
| 18 | `POST /drivers/{id}/vehicles` | ✅ Implemented | `INSERT INTO ridexpress.vehicles (...)` for driver vehicle |
| 19 | `POST /drivers/{id}/documents` | ✅ Implemented | `INSERT INTO ridexpress.user_attachments (...)` |
| 20 | `POST /drivers/{id}/banking` | ✅ Implemented | `INSERT INTO ridexpress.driver_banking (...)` |
| 21 | `GET /drivers` | ✅ Implemented | `SELECT * FROM ridexpress.drivers WHERE availability_status = 'online'` (with optional `?type=` filter) |
| 22 | `GET /drivers/payouts/pending` | ✅ Implemented | `SELECT * FROM ridexpress.drivers WHERE cumulative_balance >= 10.00` |

### 2.6 Earnings and Payout Endpoints

| # | Endpoint | Status | DB Operation |
|---|----------|--------|--------------|
| 23 | `POST /drivers/{id}/earnings` | ✅ Implemented | `INSERT INTO ridexpress.driver_earnings (...)` |
| 24 | `GET /drivers/{id}/earnings` | ✅ Implemented | `SELECT * FROM ridexpress.driver_earnings WHERE user_id = :id ORDER BY created_at DESC` |
| 25 | `POST /drivers/{id}/payouts` | ✅ Implemented | `INSERT INTO ridexpress.driver_payouts (...)` |
| 26 | `PATCH /drivers/{id}/payouts/{payoutId}` | ✅ Implemented | `UPDATE ridexpress.driver_payouts SET status = :status WHERE payout_id = :payoutId` |

### 2.7 Payment Endpoints

| # | Endpoint | Status | DB Operation |
|---|----------|--------|--------------|
| 27 | `GET /payments/{ride_id}` | ✅ Implemented | `SELECT * FROM ridexpress.payments WHERE ride_id = :ride_id` |
| 28 | `PATCH /payments/{payment_id}` | ✅ Implemented | `UPDATE ridexpress.payments SET status = :status WHERE payment_id = :payment_id` |

### 2.8 Pricing Endpoints

| # | Endpoint | Status | DB Operation |
|---|----------|--------|--------------|
| 29 | `GET /pricing` | ✅ Implemented | `SELECT * FROM ridexpress.pricing` (base fare, per-mile, per-minute, etc.) |
| 30 | `GET /pricing/surge` | ✅ Implemented | `SELECT * FROM ridexpress.surge_zones WHERE zone_id = :zone_id` |
| 31 | `GET /ride-types` | ✅ Implemented | `SELECT * FROM ridexpress.ride_types` |

---

## Phase 3 — Process APIs

> Process APIs orchestrate business logic by calling multiple System APIs.

### 3.1 User Sign Up Process API (`user-sign-up-process-api`)

> This API handles **client sign-up**, **driver sign-up/onboarding**, and **authentication** in a single project.
> Driver-specific steps (vehicle, documents, banking, background check) are handled in conditional branches of the same API.

- [ ] Create Mule 4 project `user-sign-up-process-api/`
- [ ] Implement **client sign-up** orchestration flow:
  1. Validate user input
  2. Call **database-system-api** `POST /users` to create user record
  3. Call **okta-system-api** `POST /users` to create Okta user account
  4. Call **email-system-api** `POST /send` to send welcome email with verification code
  5. Return success/failure response
- [ ] Implement **driver sign-up** orchestration flow (additional steps):
  1. Same steps 1–4 as client sign-up with `user_type = DRIVER` and Okta role = "driver"
  2. Call **square-system-api** `POST /customers` to create Square customer profile
  3. Call **database-system-api** `POST /drivers/{id}` to create driver record
  4. Return success; driver proceeds to multi-step onboarding
- [ ] Implement **driver onboarding** endpoints:
  - Vehicle registration → `database-system-api` `POST /drivers/{id}/vehicles`
  - Document upload → `database-system-api` `POST /drivers/{id}/documents` + `background-check-system-api` `POST /checks`
  - Banking setup → `database-system-api` `POST /drivers/{id}/banking`
  - Set `onboarding_status = pending_verification`
- [ ] Implement **authentication** flows:
  - `POST /auth/authenticate` → `okta-system-api` `POST /authn`
  - `POST /auth/token/refresh` → `okta-system-api` `POST /token/refresh`
  - `POST /auth/reset-password` → `okta-system-api` `POST /users/{email}/reset-password`

| # | Endpoint | Status | Description |
|---|----------|--------|-------------|
| 1 | `POST /signup` | 🔲 To implement | Client registration across DB, Okta, email |
| 2 | `POST /signup/driver` | 🔲 To implement | Driver registration (extends client flow + Square customer) |
| 3 | `POST /drivers/{id}/vehicle` | 🔲 To implement | Vehicle registration step |
| 4 | `POST /drivers/{id}/documents` | 🔲 To implement | Document upload + background check initiation |
| 5 | `POST /drivers/{id}/banking` | 🔲 To implement | Banking info storage |
| 6 | `POST /auth/authenticate` | 🔲 To implement | Okta credential validation → return tokens |
| 7 | `POST /auth/token/refresh` | 🔲 To implement | Refresh Okta access token |
| 8 | `POST /auth/reset-password` | 🔲 To implement | Trigger Okta password reset email |

### 3.2 Request Ride Process API (`request-ride-process-api`)

- [ ] Create Mule 4 project `request-ride-process-api/`
- [ ] Implement orchestration flows per RAML spec:

| # | Endpoint | Status | Description |
|---|----------|--------|-------------|
| 1 | `POST /rides` | 🔲 To implement | Create ride → calculate fare → create Square payment → find driver → notify |
| 2 | `PATCH /rides/{id}` | 🔲 To implement | Update ride status |
| 3 | `GET /driver` | 🔲 To implement | Find available driver near pickup location |
| 4 | `POST /driver/broadcast` | 🔲 To implement | Broadcast ride request to nearby drivers |
| 5 | `POST /notification/user` | 🔲 To implement | Send push notification to passenger |
| 6 | `POST /notification/driver` | 🔲 To implement | Send push notification to driver |

### 3.3 Accept Ride Process API (`accept-ride-process-api`)

- [ ] Create Mule 4 project `accept-ride-process-api/`
- [ ] Implement flow:
  1. Driver accepts ride → update ride status to `ACCEPTED_BY_DRIVER`
  2. Notify passenger that a driver has been assigned
  3. Update ride record with driver ID

| # | Endpoint | Status | Description |
|---|----------|--------|-------------|
| 1 | `POST /accept` | 🔲 To implement | Driver accepts a ride request |

### 3.4 Waiting Ride Process API (`waiting-ride-process-api`)

- [ ] Create Mule 4 project `waiting-ride-process-api/`
- [ ] Implement flow:
  1. Track driver location updates
  2. Calculate ETA to passenger
  3. Update ride status (`DRIVING_TO_PASSENGER_LOCATION` → `WAITING_FOR_PASSANGER`*)
  4. Send push notifications for driver arrival

| # | Endpoint | Status | Description |
|---|----------|--------|-------------|
| 1 | `GET /status` | 🔲 To implement | Get current waiting/ETA status |
| 2 | `PUT /arrived` | 🔲 To implement | Driver signals arrival at pickup |

### 3.5 Finish Ride Process API (`finish-ride-process-api`)

- [ ] Create Mule 4 project `finish-ride-process-api/`
- [ ] Implement flow:
  1. Update ride status to `ARRIVED_AT_DESTINATION` → `FINISHED`
  2. Process payment via Square
  3. Send ride summary to passenger
  4. Send ride summary to Salesforce for analytics
  5. Prompt for feedback

| # | Endpoint | Status | Description |
|---|----------|--------|-------------|
| 1 | `POST /finish` | 🔲 To implement | Complete ride and trigger payment |

### 3.6 Cancel Ride Process API (`cancel-ride-process-api`)

- [ ] Create Mule 4 project `cancel-ride-process-api/`
- [ ] Implement cancellation decision logic:
  1. Retrieve ride from **database-system-api** `GET /rides/{id}`
  2. Evaluate charge/no-charge rules based on ride state, timestamps, and driver ETA
  3. Call **google-maps-system-api** `GET /distance` if driver ETA check is needed
  4. Cancel without charge → **square-system-api** `PUT /orders/{orderId}` (state = CANCELED)
  5. Cancel with charge → **square-system-api** `POST /payments/{id}/commit`
  6. Update ride status to `CANCELED_FOR_REFUND` or `CANCELED_WITHOUT_REFUND` via **database-system-api** `PATCH /rides/{id}`
  7. Notify both parties via **push-notifications-system-api** `POST /notify`
  8. Driver cancellation: trigger ride reassignment via **request-ride-process-api**

| # | Endpoint | Status | Description |
|---|----------|--------|-------------|
| 1 | `POST /cancel` | 🔲 To implement | Cancel ride with charge/refund evaluation |

### 3.7 Driver Availability Process API (`driver-availability-process-api`)

- [ ] Create Mule 4 project `driver-availability-process-api/`
- [ ] Implement availability flows:
  1. Validate driver account status (must be `active`)
  2. Validate no active ride in `IN_ROUTE` state before going offline
  3. Update driver availability status via **database-system-api** `PATCH /drivers/{id}`
  4. Store location on "go online" via **database-system-api** `POST /users/{id}/location`

| # | Endpoint | Status | Description |
|---|----------|--------|-------------|
| 1 | `PATCH /drivers/{id}/status` | 🔲 To implement | Toggle driver online/offline with validations |

### 3.8 Rides Process Async API (`rides-process-async-api`) — Already Exists

> This project already exists and consumes messages from RabbitMQ.
> It will be extended with a weekly payout scheduler and payment failure retry jobs.

- [ ] Implement message processing logic in `request-ride` flow (currently only logs payload)
- [ ] Add routing logic to dispatch to the appropriate Process API based on message type
- [ ] Add error handling and dead-letter queue support
- [ ] Add database operations for ride state persistence
- [ ] **[UC-14]** Add weekly Scheduler flow (`driver-payout-scheduler`) — every Monday 00:00 UTC:
  1. `GET /drivers/payouts/pending` from **database-system-api**
  2. For each eligible driver: `POST /payouts` on **square-system-api**; `POST /drivers/{id}/payouts` on **database-system-api**
  3. Poll `GET /payouts/{id}` to confirm; update payout status
  4. Notify driver via **push-notifications-system-api**
- [ ] **[UC-13]** Add payment failure retry Scheduler (every 15 min):
  1. Query `pending_collection` and `pending_refund` payment records from **database-system-api**
  2. Retry Square commit/refund; update status or flag as `uncollected` after 24/48 h

---

## Phase 4 — System APIs (External Integrations)

> System APIs encapsulate access to external systems and services.
> Each System API provides a consistent REST contract over a single backend system.
> See [API Application Catalogue](https://github.com/RideXpress/docs/blob/main/architecture/integration-architecture/3-mulesoft-integration-implementation.md#api-application-catalogue).

### 4.1 Okta System API (`okta-system-api`)

> Provides CRUD operations for users and support of Authentication information and processes.

- [ ] Create Mule 4 project `okta-system-api/`
- [ ] Define full RAML spec (currently a stub)
- [ ] Implement endpoints:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `POST /users` | 🔲 To implement | Okta Users API — create user |
| 2 | `GET /users/{id}` | 🔲 To implement | Okta Users API — get user |
| 3 | `GET /users` | 🔲 To implement | Okta Users API — search users (`?email={email}` for duplicate check) |
| 4 | `PUT /users/{id}` | 🔲 To implement | Okta Users API — update user |
| 5 | `PATCH /users/{id}` | 🔲 To implement | Okta Users API — partial update (email, name sync from UC-17) |
| 6 | `DELETE /users/{id}` | 🔲 To implement | Okta Users API — deactivate user |
| 7 | `GET /users/{id}/session` | 🔲 To implement | Okta Sessions API — validate session token |
| 8 | `POST /authn` | 🔲 To implement | Okta Authentication API — validate credentials, return tokens |
| 9 | `POST /token/refresh` | 🔲 To implement | Okta Token API — refresh access token |
| 10 | `POST /users/{email}/reset-password` | 🔲 To implement | Okta Users API — trigger password reset email |
| 11 | `POST /token/introspect` | 🔲 To implement | Okta Token Introspection — validate OAuth tokens |

### 4.2 Google Maps System API (`google-maps-system-api`)

> Provides the functionality for geolocation and to create the best routes between drivers and passengers, and for rides.

- [ ] Create Mule 4 project `google-maps-system-api/`
- [ ] Define full RAML spec (currently a stub)
- [ ] Implement endpoints:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `GET /geocode` | 🔲 To implement | Google Geocoding API |
| 2 | `GET /places` | 🔲 To implement | Google Places API — search locations |
| 3 | `GET /places/{id}` | 🔲 To implement | Google Places API — place details |
| 4 | `GET /directions` | 🔲 To implement | Google Directions API — get route |
| 5 | `GET /distance` | 🔲 To implement | Google Distance Matrix API — ETA calculation |
| 6 | `POST /geolocation` | 🔲 To implement | Google Geocoding API — route distance + duration for fare calculation (UC-10) |
| 7 | `GET /routes/{ride_id}/eta` | 🔲 To implement | Google Directions API — ETA at destination for in-ride tracking (UC-12) |
| 8 | `GET /routes/{ride_id}` | 🔲 To implement | Google Directions API — full route for history/receipt display (UC-15) |

### 4.3 Square System API (`square-system-api`)

> Provides the CRUD operations for Payments, Orders, and Driver Payouts.
> 📄 **Technical Design Document**: [Square API Design Document](https://github.com/RideXpress/docs/blob/main/architecture/integration-architecture/system-apis/square.md)
>
> RideXpress leverages the **Quick Payments API** (payment link generation), **Orders API** (order management), and **Payouts API** (driver disbursement).
> RideXpress will NOT store sensitive user financial information — payment processing is fully delegated to Square.

- [ ] Create Mule 4 project `square-system-api/`
- [ ] Implement endpoints per existing RAML spec and new requirements:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `POST /payment-link` | 🔲 To implement | Square Checkout API — create payment link |
| 2 | `GET /orders/{orderId}` | 🔲 To implement | Square Orders API — get order |
| 3 | `PUT /orders/{orderId}` | 🔲 To implement | Square Orders API — update order fulfillment / cancel |
| 4 | `POST /payments/{id}/commit` | 🔲 To implement | Square Payments API — commit payment hold (UC-5, UC-9, UC-13) |
| 5 | `POST /customers` | 🔲 To implement | Square Customers API — create customer profile (UC-7 driver onboarding) |
| 6 | `PATCH /customers/{id}` | 🔲 To implement | Square Customers API — update customer profile (UC-17 profile management) |
| 7 | `POST /payouts` | 🔲 To implement | Square Payouts API — initiate driver bank transfer (UC-14) |
| 8 | `GET /payouts/{id}` | 🔲 To implement | Square Payouts API — check payout status (UC-14) |
| 9 | `POST /refunds` | 🔲 To implement | Square Refunds API — partial or full refund (UC-16 dispute resolution) |

**Square data mappings** (from TDD):

<details>
<summary>POST /payment-link — Request mapping</summary>

| Square Field | System API Field |
|---|---|
| `idempotency_key` | `idempotencyKey` |
| `quick_pay.name` | `name` |
| `quick_pay.price_money` | `amount` |
| `quick_pay.currency` | `currency` |
| `checkout_options.allow_tipping` | `allowTipping` |
| `checkout_options.redirect_url` | `redirectUrl` |
| `location_id` | `locationId` |

</details>

<details>
<summary>POST /payment-link — Response mapping</summary>

| Square Field | System API Field |
|---|---|
| `payment_link.order_id` | `orderId` |
| `payment_link.url` | `url` |
| `payment_link.long_url` | `longUrl` |
| `payment_link.created_at` | `createdAt` |

</details>

<details>
<summary>GET /orders/{id} — Response mapping</summary>

| Square Field | System API Field |
|---|---|
| `id` | `id` |
| `lineItems.uid` | `lineItems.uid` |
| `lineItems.quantity` | `lineItems.quantity` |
| `lineItems.name` | `lineItems.name` |
| `lineItems.price` | `lineItems.price` |
| `lineItems.currency` | `lineItems.currency` |
| `state` | `state` |
| `created_at` | `createdAt` |
| `updated_at` | `updatedAt` |
| `tenders.id` | `tenderId` |

</details>

<details>
<summary>PUT /orders/{id} — Request mapping</summary>

| Square Field | System API Field |
|---|---|
| `state` | `state` |
| `fulfillments.uid` | `fulfillmentId` |
| `location_id` | `locationId` |
| `idempotency_key` | `idempotencyKey` |

</details>

**Non-functional requirements** (from TDD):
- Availability: 24x7, target 99.99% uptime
- Transaction response time: 95% within 2 seconds
- Throughput baseline: 3 requests per ride (payment link + get order + update order)

### 4.4 Salesforce System API (`salesforce-system-api`)

> Provides the CRUD operations on Salesforce entities.
> 📐 [Salesforce objects mapping diagram](https://github.com/RideXpress/docs/blob/main/architecture/diagrams/high-level-flows/initial-sf-objects-mapping-diagram.drawio.svg)

- [ ] Create Mule 4 project `salesforce-system-api/`
- [ ] Define full RAML spec (currently a stub)
- [ ] Implement endpoints:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `POST /contacts` | 🔲 To implement | Salesforce REST API — create Contact |
| 2 | `PUT /contacts/{id}` | 🔲 To implement | Salesforce REST API — update Contact |
| 3 | `PATCH /contacts/{id}` | 🔲 To implement | Salesforce REST API — partial update Contact (account suspension via UC-16) |
| 4 | `POST /cases` | 🔲 To implement | Salesforce REST API — create Case (support ticket UC-16) |
| 5 | `POST /rides` | 🔲 To implement | Salesforce REST API — create custom Ride record for analytics |

### 4.5 Email System API (`email-system-api`)

> Provides email sending functionality (welcome emails, ride receipts, verification codes).

- [ ] Create Mule 4 project `email-system-api/`
- [ ] Define full RAML spec (currently a stub)
- [ ] Implement endpoints:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `POST /send` | 🔲 To implement | Gmail API or SMTP — send email |
| 2 | `POST /emails` | 🔲 To implement | Send verification/welcome/payout confirmation emails (UC-7 driver onboarding uses this path) |
| 3 | `POST /send/template` | 🔲 To implement | Send templated email (welcome, ride receipt, etc.) |

### 4.6 Push Notifications System API (`push-notifications-system-api`)

> Provides notifications functionality with drivers and passengers.

- [ ] Create Mule 4 project `push-notifications-system-api/`
- [ ] Define full RAML spec (currently a stub)
- [ ] Implement endpoints:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `POST /notify` | 🔲 To implement | APNs HTTP/2 API — send push notification |
| 2 | `POST /notification` | 🔲 To implement | Push notification (alternate path name used in some use cases — maps to same APNs endpoint) |
| 3 | `POST /notify/batch` | 🔲 To implement | APNs — send batch notifications |

### 4.7 Background Check System API (`background-check-system-api`) — Mocked

> Provides driver background check initiation and status retrieval. This is a mocked 3rd-party integration for MVP.
> The mock simulates a realistic response pattern: check initiated → status "pending" → status "approved" / "rejected" after a configurable delay.

- [ ] Create Mule 4 project `background-check-system-api/`
- [ ] Define RAML spec
- [ ] Implement mocked endpoints:

| # | Endpoint | Status | Mock Behavior |
|---|----------|--------|---------------|
| 1 | `POST /checks` | 🔲 To implement | Accept driver ID + document URLs; return `checkId` and status = "pending" |
| 2 | `GET /checks/{id}` | 🔲 To implement | Return configurable status: "pending", "approved", or "rejected" |

---

## Phase 5 — Cross-Cutting Concerns

> See [Common Services](https://github.com/RideXpress/docs/blob/main/architecture/anypoint-platform-architecture/common-services.md) and [MuleSoft Best Practices](https://github.com/RideXpress/docs/blob/main/architecture/common-mulesoft-best-practices.md).

### 5.1 Error Handling Strategy

> From [Error Handling — Common Services](https://github.com/RideXpress/docs/blob/main/architecture/anypoint-platform-architecture/common-services.md#error-handling)

- [ ] Create a common `errors.xml` for each project with standard error handling
- [ ] Standard error response format: `{ "message": "...", "errorType": "...", "correlationId": "..." }`
- [ ] Error codes: 400, 401, 403, 404, 405, 408, 409, 413, 429, 500
- [ ] APIs use APIKit error configurations with logging of: date, `correlationId`, error message, error type
- [ ] Async processes use a common error handler that logs and has standardized reprocessing mechanism
- [ ] Dead-letter queue (`rides.dlq`) for failed async messages
- [ ] Use `#[error.errorType]` to define retry strategies (e.g., `HTTP:CONNECTIVITY` → `until-successful`)
- [ ] Retry policies for transient failures (HTTP 503, connection timeouts)

### 5.2 Security

> From [Security Architecture](https://github.com/RideXpress/docs/blob/main/architecture/anypoint-platform-architecture/security-architecture.md)

- [ ] OAuth 2.0 token validation on Experience API using Okta
- [ ] Client Credentials enforcement on Process & System APIs
- [ ] Secure properties encryption — secrets saved in GitHub Secrets, accessible via GitHub Actions
- [ ] Safely hidden properties for all sensitive CloudHub attributes
- [ ] TLS configuration for all HTTP listeners
- [ ] API policies via API Manager: rate limiting, IP whitelisting
- [ ] Data protection in motion (TLS) and at rest (encryption)

### 5.3 Observability

> From [Operations Architecture](https://github.com/RideXpress/docs/blob/main/architecture/anypoint-platform-architecture/operations-architecture.md)

- [ ] Correlation ID (`X-Transaction-Id`) propagation across all API layers
- [ ] Structured JSON logging using [JSON Logger](https://github.com/mulesoft-consulting/json-logger) format
- [ ] Health check endpoint: `GET /health-check` on every project (for Anypoint Functional Monitoring)
- [ ] Anypoint Monitoring dashboards
- [ ] Custom alerts for error rates and latency
- [ ] Log format standard:
  ```json
  {
    "priority": "INFO",
    "correlationId": "e58ed763-928c-4155-bee9-fdbaaadc15f3",
    "timestamp": "2012-04-23T18:25:43.511Z",
    "message": "This is a log entry",
    "applicationName": "square-system-api",
    "applicationVersion": "1.0.0-SNAPSHOT",
    "environment": "sandbox"
  }
  ```

### 5.4 Testing (MUnit)

- [ ] Add MUnit tests for each Experience API flow
- [ ] Add MUnit tests for each Database System API flow
- [ ] Add MUnit tests for each Process API flow
- [ ] Mock external services in System API tests
- [ ] Target: >80% code coverage per project
- [ ] UAT sessions with cross-functional teams
- [ ] Regression testing suites

### 5.5 CI/CD

> See [CI/CD Pipeline](#cicd-pipeline) section below for full details.

---

## Database Schema

> PostgreSQL database: `ridexpress` schema

### Users Table

```sql
CREATE TABLE ridexpress.users (
    user_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_name     VARCHAR(50) UNIQUE NOT NULL,
    email         VARCHAR(255) UNIQUE NOT NULL,
    mobile        VARCHAR(20),
    first_name    VARCHAR(100) NOT NULL,
    middle_name   VARCHAR(100),
    last_name     VARCHAR(100) NOT NULL,
    user_type     VARCHAR(20) NOT NULL CHECK (user_type IN ('DRIVER', 'PASSENGER')),
    address       TEXT,
    driver_license VARCHAR(50),
    is_active     BOOLEAN DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Vehicles Table

```sql
CREATE TABLE ridexpress.vehicles (
    vehicle_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES ridexpress.users(user_id),
    make            VARCHAR(50) NOT NULL,
    model           VARCHAR(50) NOT NULL,
    year            INTEGER NOT NULL,
    license_plate   VARCHAR(20) NOT NULL,
    insurance_policy VARCHAR(50) NOT NULL,
    is_active       BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Rides Table

> **Note**: The status enum value `WAITING_FOR_PASSANGER` contains a known typo inherited from the
> RAML spec (`ride-data-type.raml`). The DB schema intentionally matches the RAML contract.
> Consider correcting this to `WAITING_FOR_PASSENGER` in a future RAML spec update across all layers.

```sql
CREATE TABLE ridexpress.rides (
    ride_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES ridexpress.users(user_id),
    driver_id         UUID REFERENCES ridexpress.users(user_id),
    status            VARCHAR(50) NOT NULL DEFAULT 'NEW'
                      CHECK (status IN (
                          'NEW', 'WAITING_FOR_DRIVER', 'DRIVING_TO_PASSENGER_LOCATION',
                          'WAITING_FOR_PASSANGER', 'CANCELED_FOR_REFUND',
                          'CANCELED_WITHOUT_REFUND', 'PASSENGER_GETS_INTO_THE_CAR',
                          'IN_ROUTE', 'ARRIVED_AT_DESTINATION', 'FINISHED',
                          'ACCEPTED_BY_DRIVER'
                      )),
    rate              DECIMAL(10,2),
    pickup_location   VARCHAR(255),
    destination       VARCHAR(255),
    destination_name  VARCHAR(255),
    start_location    VARCHAR(255),
    end_location      VARCHAR(255),
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### User Locations Table (Real-time Tracking)

```sql
CREATE TABLE ridexpress.user_locations (
    location_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES ridexpress.users(user_id),
    latitude      DECIMAL(10,7) NOT NULL,
    longitude     DECIMAL(10,7) NOT NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_locations_user_id ON ridexpress.user_locations(user_id, created_at DESC);
```

### Ride Feedback Table

```sql
CREATE TABLE ridexpress.ride_feedback (
    feedback_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id       UUID NOT NULL REFERENCES ridexpress.rides(ride_id),
    user_id       UUID NOT NULL REFERENCES ridexpress.users(user_id),
    rating        INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment       TEXT,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Payments Table

```sql
CREATE TABLE ridexpress.payments (
    payment_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id         UUID NOT NULL REFERENCES ridexpress.rides(ride_id),
    square_order_id VARCHAR(100),
    amount          DECIMAL(10,2) NOT NULL,
    currency        VARCHAR(3) DEFAULT 'USD',
    status          VARCHAR(20) NOT NULL DEFAULT 'HOLD'
                    CHECK (status IN ('HOLD', 'PAID', 'REJECTED', 'REFUND')),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### User Attachments Table

```sql
CREATE TABLE ridexpress.user_attachments (
    attachment_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES ridexpress.users(user_id),
    document_type   VARCHAR(50) NOT NULL,
    file_name       VARCHAR(255) NOT NULL,
    file_path       VARCHAR(500) NOT NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Users Table — Additional Columns Required

> The existing `users` table must be extended with fields identified in `entity-details.md`:

```sql
ALTER TABLE ridexpress.users
    ADD COLUMN okta_id              VARCHAR(50)  UNIQUE,
    ADD COLUMN square_customer_id   VARCHAR(50)  UNIQUE,
    ADD COLUMN profile_photo_url    VARCHAR(500),
    ADD COLUMN role                 VARCHAR(20)  NOT NULL DEFAULT 'PASSENGER'
                                    CHECK (role IN ('CLIENT', 'DRIVER', 'BOTH')),
    ADD COLUMN status               VARCHAR(30)  NOT NULL DEFAULT 'active'
                                    CHECK (status IN ('active', 'pending_verification', 'suspended', 'deactivated'));
```

### Drivers Table

```sql
CREATE TABLE ridexpress.drivers (
    user_id                  UUID PRIMARY KEY REFERENCES ridexpress.users(user_id),
    license_number           VARCHAR(50)  NOT NULL,
    license_expiry           DATE         NOT NULL,
    license_photo_url        VARCHAR(500),
    insurance_doc_url        VARCHAR(500),
    background_check_id      VARCHAR(100),
    background_check_status  VARCHAR(20)  NOT NULL DEFAULT 'pending'
                             CHECK (background_check_status IN ('pending', 'approved', 'rejected')),
    onboarding_status        VARCHAR(30)  NOT NULL DEFAULT 'incomplete'
                             CHECK (onboarding_status IN ('incomplete', 'pending_verification', 'active', 'rejected')),
    availability_status      VARCHAR(10)  NOT NULL DEFAULT 'offline'
                             CHECK (availability_status IN ('online', 'offline')),
    average_rating           DECIMAL(3,2),
    total_rides              INTEGER      NOT NULL DEFAULT 0,
    cumulative_balance       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    created_at               TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at               TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Driver Banking Table

> Stores tokenized banking information for driver payouts. Raw account numbers are never stored — Square tokenizes them.

```sql
CREATE TABLE ridexpress.driver_banking (
    banking_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES ridexpress.users(user_id),
    bank_name         VARCHAR(100) NOT NULL,
    account_holder    VARCHAR(200) NOT NULL,
    routing_number    VARCHAR(20)  NOT NULL,
    account_token     VARCHAR(255) NOT NULL,   -- tokenized by Square; raw account never stored
    is_active         BOOLEAN DEFAULT TRUE,
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Rides Table — Additional Columns Required

> The existing `rides` table must be extended with fields required by new use cases:

```sql
ALTER TABLE ridexpress.rides
    ADD COLUMN ride_type         VARCHAR(20)    CHECK (ride_type IN ('ECONOMY', 'COMFORT', 'PREMIUM')),
    ADD COLUMN otp               VARCHAR(4),
    ADD COLUMN estimated_fare    DECIMAL(10,2),
    ADD COLUMN actual_fare       DECIMAL(10,2),
    ADD COLUMN surge_multiplier  DECIMAL(3,2)   NOT NULL DEFAULT 1.00,
    ADD COLUMN surge_zone_id     VARCHAR(50),
    ADD COLUMN shared_link_token VARCHAR(100)   UNIQUE;  -- for real-time trip sharing (UC-12)
```

### Ride Types Table

```sql
CREATE TABLE ridexpress.ride_types (
    ride_type_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name             VARCHAR(20)  NOT NULL UNIQUE CHECK (name IN ('ECONOMY', 'COMFORT', 'PREMIUM')),
    description      TEXT,
    price_multiplier DECIMAL(4,2) NOT NULL DEFAULT 1.00,
    min_vehicle_year INTEGER,
    is_active        BOOLEAN DEFAULT TRUE,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed data
INSERT INTO ridexpress.ride_types (name, description, price_multiplier, min_vehicle_year)
VALUES
    ('ECONOMY',  'Affordable everyday rides',             1.00, NULL),
    ('COMFORT',  'Newer vehicles with more legroom',      1.30, 2020),
    ('PREMIUM',  'Luxury vehicles with top-rated drivers',2.00, 2022);
```

### Pricing Table

```sql
CREATE TABLE ridexpress.pricing (
    pricing_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    base_fare        DECIMAL(10,2) NOT NULL DEFAULT 2.50,
    per_mile_rate    DECIMAL(10,2) NOT NULL DEFAULT 1.25,
    per_minute_rate  DECIMAL(10,2) NOT NULL DEFAULT 0.20,
    minimum_fare     DECIMAL(10,2) NOT NULL DEFAULT 5.00,
    booking_fee      DECIMAL(10,2) NOT NULL DEFAULT 1.50,
    is_active        BOOLEAN DEFAULT TRUE,
    effective_from   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Surge Zones Table

```sql
CREATE TABLE ridexpress.surge_zones (
    zone_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zone_name           VARCHAR(100) NOT NULL,
    boundary_geojson    TEXT,                       -- GeoJSON polygon defining the zone
    surge_multiplier    DECIMAL(3,2) NOT NULL DEFAULT 1.00,
    demand_count        INTEGER NOT NULL DEFAULT 0, -- ride requests in last 10 minutes
    supply_count        INTEGER NOT NULL DEFAULT 0, -- online drivers in last 5 minutes
    last_calculated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Driver Earnings Table

```sql
CREATE TABLE ridexpress.driver_earnings (
    earning_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              UUID NOT NULL REFERENCES ridexpress.users(user_id),
    ride_id              UUID NOT NULL REFERENCES ridexpress.rides(ride_id),
    gross_fare           DECIMAL(10,2) NOT NULL,
    platform_commission  DECIMAL(10,2) NOT NULL,
    tip_amount           DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    cancellation_portion DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    deductions           DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    net_earnings         DECIMAL(10,2) NOT NULL,
    created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Driver Payouts Table

```sql
CREATE TABLE ridexpress.driver_payouts (
    payout_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES ridexpress.users(user_id),
    square_payout_id VARCHAR(100),
    amount           DECIMAL(10,2) NOT NULL,
    currency         VARCHAR(3) DEFAULT 'USD',
    status           VARCHAR(20) NOT NULL DEFAULT 'processing'
                     CHECK (status IN ('processing', 'completed', 'failed')),
    payout_period    DATE NOT NULL,               -- Monday of the payout week
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Payments Table — Additional Status Values Required

> The existing `payments` table `status` check constraint must include payment failure handling states:

```sql
ALTER TABLE ridexpress.payments
    DROP CONSTRAINT payments_status_check,
    ADD CONSTRAINT payments_status_check
        CHECK (status IN ('HOLD', 'PAID', 'REJECTED', 'REFUND',
                          'PENDING_COLLECTION', 'PENDING_REFUND', 'UNCOLLECTED'));
```

---

## Integration Infrastructure

### RabbitMQ Queues

| Queue Name | Producer | Consumer | Purpose |
|------------|----------|----------|---------|
| `rides` | Experience API (`POST /rides`) | `rides-process-async-api` | New ride requests for async processing |
| `rides.feedback` | Experience API (`POST /rides/{id}/feedback`) | `rides-process-async-api` | Ride feedback for async processing |
| `rides.status` | Process APIs | `rides-process-async-api` | Ride status change events |
| `notifications` | Process APIs | Notification workers | Push notification dispatch |
| `rides.dlq` | Error handler | Manual review | Dead-letter queue for failed messages |

### External Service Connections

| Service | Protocol | Auth Method | Config Property Prefix |
|---------|----------|-------------|----------------------|
| PostgreSQL | JDBC | Username/Password | `postgres.*` |
| RabbitMQ | AMQP | Username/Password | `rabbitmq.*` |
| Google Maps | HTTPS | API Key | `googlemaps.*` |
| Okta | HTTPS | OAuth 2.0 / API Token | `okta.*` |
| Square | HTTPS | OAuth 2.0 / Bearer Token | `square.*` |
| Salesforce | HTTPS | OAuth 2.0 | `salesforce.*` |
| Gmail | HTTPS/SMTP | OAuth 2.0 | `gmail.*` |
| APNs | HTTP/2 | Token-based (JWT) | `apns.*` |
| Background Check (mocked) | HTTPS | API Key | `backgroundcheck.*` |

---

## CI/CD Pipeline

> From [CI/CD Design](https://github.com/RideXpress/docs/blob/main/architecture/ci-cd-design.md) and [SDLC](https://github.com/RideXpress/docs/blob/main/architecture/anypoint-platform-architecture/software-development-lifecycle.md#build-and-deployment-automation-cicd).
> The solution leverages **GitHub Actions** with **Maven** and **Anypoint CLI**.

### Pipeline 1: Pull from Design Center

> Retrieves latest RAML specs from Anypoint Design Center to keep local development in sync.

- [ ] List all Design Center projects
- [ ] For each project: if it exists locally → download into `{project}/src/main/resources/api`; if not → download into `design-center/`
- [ ] Open Pull Request to review latest changes

### Pipeline 2: Push to Design Center

> Publishes local RAML changes back to Anypoint Exchange.

- [ ] For each project inside `design-center/` directory → publish to Exchange

### Pipeline 3: Build and Deploy

> Triggered on every commit to main branch.

- [ ] Run MUnit tests
- [ ] Publish application to Anypoint Exchange
- [ ] Publish API to API Manager
- [ ] Create API SLAs
- [ ] Configure API Policies
- [ ] Pull API configuration from API Manager
- [ ] Deploy application to Runtime Manager
- [ ] Publish to GitHub Packages

### Pipeline 4: Release

> Finalizes the release process and promotes stable artifacts.

- [ ] Read artifacts to release from configuration file
- [ ] For each artifact:
  - [ ] Update asset in Exchange to mark as Stable
  - [ ] Promote API in API Manager to production
  - [ ] Promote application in Runtime Manager
- [ ] Validate deployment
- [ ] Tag code in GitHub with new release version

---

## Conventions & Best Practices

> From [SDLC — Development Standards and Naming Conventions](https://github.com/RideXpress/docs/blob/main/architecture/anypoint-platform-architecture/software-development-lifecycle.md#development-standards-and-naming-conventions) and [MuleSoft Best Practices](https://github.com/RideXpress/docs/blob/main/architecture/common-mulesoft-best-practices.md).

### Project & API Naming

| Category | Convention | Examples |
|----------|-----------|----------|
| **Experience APIs** | `{consumer}-experience-api` | `mobile-experience-api` |
| **Process APIs** | `{use-case}-process-api` | `request-ride-process-api`, `user-sign-up-process-api` |
| **System APIs** | `{system}-system-api` | `okta-system-api`, `square-system-api`, `database-system-api` |
| **Maven Artifact ID** | Full names, kebab-case | `mobile-experience-api`, `salesforce-system-api` |
| **CloudHub Domain** | `ridexpress-{env}-{short-name}` | `ridexpress-sandbox-mobile`, `ridexpress-prd-square` |
| **API Version** | `v1`, `v2`, `v{n}` — only increment for breaking changes | `/v1/users`, `/v1/rides` |

### Flow & Variable Naming

| Category | Convention | Examples |
|----------|-----------|----------|
| **API-generated flows** | Keep out-of-the-box convention | `get:\user:router`, `post:\rides:router` |
| **Implementation flows** | camelCase with action + `Flow` suffix | `getUserIdFlow`, `aggregateResponseFlow` |
| **Variables** | camelCase, simple names | `sfdcAccountId`, `oktaUserId`, `databaseFieldName` |

### Connector Configuration Naming

Convention: `{connector_type}-{system_instance}-config` (kebab-case)

| Example | Description |
|---------|-------------|
| `http-listener-config` | HTTP listener |
| `http-request-okta-config` | HTTP request to Okta |
| `database-ridexpress-config` | PostgreSQL connection |
| `amqp-rides-config` | RabbitMQ connection |
| `sfdc-main-config` | Salesforce connection |

### DataWeave Files

- Location: `src/main/resources/dwl/`
- Naming: `{http_method}-{http_resource}-{request|response}.dwl` (kebab-case)
- Examples: `get-accounts-response.dwl`, `post-ride-request.dwl`, `put-contact-response.dwl`

### API Body Format

- Default: JSON (`Content-Type: application/json`)
- Field naming: **camelCase** (e.g., `driverId`, `firstName`, `pickupLocation`)
- Resources: plural nouns in URL paths (`/users`, `/rides`, `/contacts`)

### Configuration

- All environment-specific values externalized to `config.yaml`
- Sensitive values use `${ext.*}` pattern pointing to secure properties file
- Secret file path configured via `-Dsecrets.path` JVM argument
- Environment-specific properties in separate files (e.g., `square-staging.yaml`, `square-prod.yaml`)
- Secrets saved in GitHub Secrets, accessible via GitHub Actions

### HTTP Request Configuration

Each downstream API connection should be defined as an `http:request-config` with:
- Externalized `host`, `port`, `basePath` in properties
- Response timeout configuration
- Connection idle timeout

### Error Handling

- Global error handler in the main API flow for APIKit errors (`errors.xml`)
- Per-flow error handlers for downstream call failures
- Standard error response: `{ "message": "...", "errorType": "...", "correlationId": "..." }`
- Use `#[error.errorType]` for retry strategy decisions (e.g., `HTTP:CONNECTIVITY` → `until-successful`)
- Map HTTP error codes from downstream APIs appropriately

### Logging

- Format: JSON using [JSON Logger](https://github.com/mulesoft-consulting/json-logger) convention
- Always log at flow entry with `level="INFO"`
- Log payload at `level="DEBUG"` only (not INFO, to avoid PII in production)
- Include `correlationId`, `applicationName`, `applicationVersion`, `environment` in all log entries
- Use rolling file appender with 10 MB limit, max 10 files

### Version Control

- **Branching**: [Git Flow](https://www.gitkraken.com/learn/git/git-flow) — main branch for stable, feature branches per GitHub issue
- **Versioning**: [Semantic Versioning](https://semver.org) — `MAJOR.MINOR.PATCH` + Maven `SNAPSHOT` for development
- **PRs**: Require at least 1 code review before merging to main

### Deployment Sizing (MVP)

| Worker Size | Worker Memory | Heap Memory | Disk Storage |
|-------------|---------------|-------------|--------------|
| 0.1 vCores | 1 GB | 500 MB | 8 GB |

| Mule Runtime Version |
|---------------------|
| 4.6.1+ |

---

## Priority Order

| Priority | Phase | Item | Use Case | Justification |
|----------|-------|------|----------|---------------|
| **P0** | 2 | Database System API — Users CRUD + Drivers table | UC-1, UC-2, UC-7 | Foundation for all user and driver operations |
| **P0** | 2 | Database System API — Rides CRUD + Pricing tables | UC-2, UC-3, UC-10, UC-11 | Foundation for all ride operations |
| **P1** | 1 | Experience API — `POST /user` (via user-sign-up) | UC-1 | Core user registration flow |
| **P1** | 1 | Experience API — `POST /auth/login`, `POST /auth/token/refresh` | UC-6 | Authentication — required before any other feature |
| **P1** | 1 | Experience API — `POST /rides` and `POST /rides/estimate` | UC-2, UC-10 | Core ride request + fare estimation flow |
| **P1** | 3 | User Sign Up Process API — client sign-up + auth endpoints | UC-1, UC-6 | Orchestrates user creation and authentication |
| **P1** | 3 | Request Ride Process API — incl. pricing calculate | UC-2, UC-10, UC-11 | Orchestrates ride lifecycle and fare calculation |
| **P1** | 4 | Okta System API — core auth endpoints | UC-1, UC-6 | Authentication & authorization foundation |
| **P2** | 1 | Experience API — remaining ride lifecycle endpoints | UC-3, UC-4, UC-5 | Ride tracking features |
| **P2** | 1 | Experience API — `PATCH /rides/{id}/cancel` | UC-9 | Ride cancellation — critical for operations |
| **P2** | 1 | Experience API — `PATCH /drivers/{id}/status`, `POST /drivers/{id}/location` | UC-8 | Driver availability — required for ride matching |
| **P2** | 3 | Cancel Ride Process API | UC-9 | Ride cancellation with charge/refund rules |
| **P2** | 3 | Driver Availability Process API | UC-8 | Driver online/offline management |
| **P2** | 3 | User Sign Up Process API — driver onboarding branch | UC-7 | Driver registration and onboarding |
| **P2** | 4 | Google Maps System API | UC-2, UC-4, UC-10 | Location search, routing, ETA |
| **P2** | 4 | Square System API — core payment endpoints | UC-2, UC-5, UC-9, UC-13 | Payment processing and cancellation |
| **P2** | 4 | Background Check System API (mocked) | UC-7 | Driver onboarding verification |
| **P3** | 3 | Accept Ride Process API | UC-3 | Ride acceptance lifecycle |
| **P3** | 3 | Waiting Ride Process API | UC-4 | Driver tracking and ETA |
| **P3** | 3 | Finish Ride Process API — incl. earnings recording | UC-5, UC-14 | Ride completion, payment confirmation |
| **P3** | 3 | Rides Process Async API — payout scheduler + payment retry | UC-14, UC-13 | Driver payouts and payment failure recovery |
| **P3** | 4 | Square System API — payout + customer endpoints | UC-7, UC-14 | Driver payouts and customer profile sync |
| **P3** | 4 | Salesforce / Email / Push Notifications System APIs | UC-1, UC-5, UC-7 | Analytics, notifications |
| **P3** | 1 | Experience API — ride history and receipt endpoints | UC-15 | Ride history and receipts |
| **P3** | 1 | Experience API — real-time tracking endpoints | UC-12 | In-ride GPS tracking (HTTP polling) |
| **P3** | 1 | Experience API — profile management + support ticket | UC-16, UC-17 | Support and profile |
| **P3** | 5 | Cross-cutting: MUnit tests, security, observability | All | Quality & production readiness |
| **P4** | 5 | CI/CD Pipelines (4 pipelines) | All | Automated build, deploy, release |
| **P5** | — | Notification Preferences (UC-NOTIF-01) | UC-NOTIF-01 | Deferred to later phase (Low priority) |

---

## Contributing

> For contributing guidelines, sprint management, task definitions, and labels, see [Contributing — RideXpress/docs](https://github.com/RideXpress/docs/blob/main/contributing/README.md).

**Key points**:
- Tasks are tracked via GitHub Issues and GitHub Projects
- Size estimation: 1 point = 2 hours, 2 points = 4 hours, 3 and 5 points for larger tasks
- Labels: `documentation`, `api-design`, `implementation`, `test`, `deploy`, `ci-cd`, plus project-specific labels
- Sprint duration: 2 weeks
- PRs require at least 1 review from a team member
- Feature branches created from GitHub Issues
