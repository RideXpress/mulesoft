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
| 7 | Driver arrives → update status to `WAITING_FOR_PASSANGER` | System | `database-system-api` → `PATCH /ride/{id}` |
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

### Ride State Machine

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
| `user-sign-up-process-api` | Process | `user-sign-up-process-api` | `ridexpress-{env}-user-sign-up` | Orchestrates user registration across systems |
| `request-ride-process-api` | Process | `request-ride-process-api` | `ridexpress-{env}-request-ride` | Orchestrates ride request, fare calculation, driver matching |
| `accept-ride-process-api` | Process | `accept-ride-process-api` | `ridexpress-{env}-accept-ride` | Orchestrates ride acceptance by driver |
| `waiting-ride-process-api` | Process | `waiting-ride-process-api` | `ridexpress-{env}-wait-for-ride` | Orchestrates waiting/tracking phase |
| `finish-ride-process-api` | Process | `finish-ride-process-api` | `ridexpress-{env}-finish-ride` | Orchestrates ride completion, payment, feedback |
| `okta-system-api` | System | `okta-system-api` | `ridexpress-{env}-okta` | CRUD for users + authentication/OAuth support |
| `square-system-api` | System | `square-system-api` | `ridexpress-{env}-square` | Payment links, orders, refunds via Square |
| `salesforce-system-api` | System | `salesforce-system-api` | `ridexpress-{env}-salesforce` | CRUD on Salesforce entities for analytics |
| `google-maps-system-api` | System | `google-maps-system-api` | `ridexpress-{env}-google-maps` | Geolocation, route optimization, ETA |
| `database-system-api` | System | `database-system-api` | `ridexpress-{env}-db` | CRUD for non-sensitive data in PostgreSQL |
| `push-notifications-system-api` | System | `push-notifications-system-api` | `ridexpress-{env}-push-notifications` | Push notifications to drivers and passengers |
| `email-system-api` | System | `email-system-api` | `ridexpress-{env}-email` | Email sending (welcome, receipts, verifications) |

> **Note**: The existing `ridexpress-experience-api` project maps to `mobile-experience-api` in the docs catalog.
> The existing `rides-process-async-api` is a supporting async consumer that routes messages to the appropriate Process APIs.

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
├── rides-process-async-api/           # ✅ Async ride processing (RabbitMQ consumer)
├── database-system-api/               # 🔲 To be created — Database System API
├── user-sign-up-process-api/          # 🔲 To be created — User Sign Up Process API
├── request-ride-process-api/          # 🔲 To be created — Request Ride Process API
├── accept-ride-process-api/           # 🔲 To be created — Accept Ride Process API
├── waiting-ride-process-api/          # 🔲 To be created — Waiting Ride Process API
├── finish-ride-process-api/           # 🔲 To be created — Finish Ride Process API
├── okta-system-api/                   # 🔲 To be created — Okta integration
├── google-maps-system-api/            # 🔲 To be created — Google Maps integration
├── square-system-api/                 # 🔲 To be created — Square payments integration
├── salesforce-system-api/             # 🔲 To be created — Salesforce CRM integration
├── email-system-api/                  # 🔲 To be created — Email notification integration
├── push-notifications-system-api/     # 🔲 To be created — Push notifications (APNs)
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

### 1.1 User Endpoints (`/user`)

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

### 1.2 Rides Endpoints (`/rides`)

| # | Endpoint | Flow Name | Status | Notes |
|---|----------|-----------|--------|-------|
| 9 | `GET /rides` | `get:\rides:router` | 🟡 Partial | Calls `get-rides-impl` sub-flow (direct DB query). Should call **database-system-api** instead |
| 10 | `POST /rides` | `post:\rides:router` | 🟡 Partial | Publishes to RabbitMQ. Should include DataWeave transformation and call **request-ride-process-api** |
| 11 | `GET /rides/{id}` | `get:\rides\(id):router` | 🔲 Stub only | Call **database-system-api** `GET /ride/{id}` |
| 12 | `GET /rides/{id}/passenger` | `get:\rides\(id)\passenger:router` | 🔲 Stub only | Call **database-system-api** to get passenger details for ride |
| 13 | `GET /rides/{id}/passenger/location` | `get:\rides\(id)\passenger\location:router` | 🔲 Stub only | Call **database-system-api** `GET /users/{passengerId}/location` |
| 14 | `GET /rides/{id}/driver` | `get:\rides\(id)\driver:router` | 🔲 Stub only | Call **database-system-api** to get driver details for ride |
| 15 | `GET /rides/{id}/driver/location` | `get:\rides\(id)\driver\location:router` | 🔲 Stub only | Call **database-system-api** `GET /users/{driverId}/location` + compute arrival time |
| 16 | `GET /rides/{id}/payment` | `get:\rides\(id)\payment:router` | 🔲 Stub only | Call **square-system-api** to retrieve payment status |
| 17 | `GET /rides/{id}/route` | `get:\rides\(id)\route:router` | 🔲 Stub only | Call **google-maps-system-api** for route details |
| 18 | `POST /rides/{id}/feedback` | `post:\rides\(id)\feedback:router` | 🟡 Partial | Publishes to RabbitMQ. Should transform payload and include ride ID |
| 19 | `GET /rides/{id}/status` | `get:\rides\(id)\status:router` | 🔲 Stub only | Call **database-system-api** `GET /ride/{id}` and extract status + arrival time |
| 20 | `PUT /rides/{id}/status` | `put:\rides\(id)\status:router` | 🔲 Stub only | Call **database-system-api** `PATCH /ride/{id}` to update status |
| 21 | `GET /rides/{id}/summary` | `get:\rides\(id)\summary:router` | 🔲 Stub only | Aggregate data: ride details + passenger info + driver info + route from multiple APIs |

### 1.3 Geolocations Endpoints (`/geolocations`)

| # | Endpoint | Flow Name | Status | Notes |
|---|----------|-----------|--------|-------|
| 22 | `GET /geolocations` | `get:\geolocations:router` | 🔲 Stub only | Call **google-maps-system-api** for location search |
| 23 | `GET /geolocations/{id}` | `get:\geolocations\(id):router` | 🔲 Stub only | Call **google-maps-system-api** for place details |

### 1.4 Experience API — Infrastructure Improvements

- [ ] **Error handling**: Add `on-error-continue` / `on-error-propagate` in each flow for downstream call failures
- [ ] **HTTP request configurations**: Configure `google-maps`, `okta`, `square` request-configs with proper basePath, host, port properties
- [ ] **DataWeave transformations**: Transform between Experience API data model and downstream API data models
- [ ] **Correlation ID / X-Transaction-Id**: Propagate the `X-Transaction-Id` header to all downstream calls
- [ ] **OAuth token validation**: Implement token introspection via Okta before processing requests
- [ ] **Response mapping**: Map downstream API responses to the RAML-defined response schemas

### 1.5 Experience API — Direct DB Access Refactoring

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

- [ ] Create Mule 4 project `database-system-api/` with standard structure
- [ ] Add `pom.xml` with dependencies: HTTP Connector, DB Connector, APIKit, PostgreSQL driver
- [ ] Add `config.xml` with HTTP listener, APIKit router, and PostgreSQL connection config
- [ ] Add `config.properties` with externalized database connection properties
- [ ] Add RAML spec from `design-center/db-system-api/db-system-api.raml`
- [ ] Add `mule-artifact.json`
- [ ] Add `log4j2.xml` configuration

### 2.2 User Endpoints

| # | Endpoint | Status | DB Operation |
|---|----------|--------|--------------|
| 1 | `POST /users` | 🔲 To implement | `INSERT INTO ridexpress.users (...)` |
| 2 | `GET /users` | 🔲 To implement | `SELECT * FROM ridexpress.users` |
| 3 | `GET /users/{id}` | 🔲 To implement | `SELECT * FROM ridexpress.users WHERE user_id = :id` |
| 4 | `PATCH /users/{id}` | 🔲 To implement | `UPDATE ridexpress.users SET ... WHERE user_id = :id` |
| 5 | `GET /users/{id}/location` | 🔲 To implement | `SELECT * FROM ridexpress.user_locations WHERE user_id = :id ORDER BY created_at DESC LIMIT 1` |
| 6 | `POST /users/{id}/location` | 🔲 To implement | `INSERT INTO ridexpress.user_locations (...)` |
| 7 | `POST /users/{id}/feedback` | 🔲 To implement | `INSERT INTO ridexpress.user_feedback (...)` |

### 2.3 Ride Endpoints

| # | Endpoint | Status | DB Operation |
|---|----------|--------|--------------|
| 8 | `POST /rides` | 🔲 To implement | `INSERT INTO ridexpress.rides (...)` |
| 9 | `GET /ride/{id}` | 🔲 To implement | `SELECT * FROM ridexpress.rides WHERE ride_id = :id` |
| 10 | `PATCH /ride/{id}` | 🔲 To implement | `UPDATE ridexpress.rides SET ... WHERE ride_id = :id` |
| 11 | `POST /ride/{id}/feedback` | 🔲 To implement | `INSERT INTO ridexpress.ride_feedback (...)` |

### 2.4 Vehicle Endpoints

| # | Endpoint | Status | DB Operation |
|---|----------|--------|--------------|
| 12 | `GET /users/{id}/vehicles` | 🔲 To implement | `SELECT * FROM ridexpress.vehicles WHERE user_id = :id` |
| 13 | `POST /users/{id}/vehicles` | 🔲 To implement | `INSERT INTO ridexpress.vehicles (...)` |
| 14 | `PUT /users/{id}/vehicles/{vehicleId}` | 🔲 To implement | `UPDATE ridexpress.vehicles SET ... WHERE vehicle_id = :vehicleId` |

---

## Phase 3 — Process APIs

> Process APIs orchestrate business logic by calling multiple System APIs.

### 3.1 User Sign Up Process API (`user-sign-up-process-api`)

- [ ] Create Mule 4 project `user-sign-up-process-api/`
- [ ] Implement orchestration flow:
  1. Validate user input
  2. Call **database-system-api** `POST /users` to create user record
  3. Call **okta-system-api** to create Okta user account
  4. Call **email-system-api** to send welcome email
  5. Return success/failure response

| # | Endpoint | Status | Description |
|---|----------|--------|-------------|
| 1 | `POST /signup` | 🔲 To implement | Orchestrates user registration across systems |

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

### 3.6 Rides Process Async API (`rides-process-async-api`) — Already Exists

> This project already exists and consumes messages from RabbitMQ.

- [ ] Implement message processing logic in `request-ride` flow (currently only logs payload)
- [ ] Add routing logic to dispatch to the appropriate Process API based on message type
- [ ] Add error handling and dead-letter queue support
- [ ] Add database operations for ride state persistence

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
| 3 | `PUT /users/{id}` | 🔲 To implement | Okta Users API — update user |
| 4 | `DELETE /users/{id}` | 🔲 To implement | Okta Users API — deactivate user |
| 5 | `POST /token/introspect` | 🔲 To implement | Okta Token Introspection — validate OAuth tokens |

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

### 4.3 Square System API (`square-system-api`)

> Provides the CRUD operations for Payments.
> 📄 **Technical Design Document**: [Square API Design Document](https://github.com/RideXpress/docs/blob/main/architecture/integration-architecture/system-apis/square.md)
>
> RideXpress leverages the **Quick Payments API** (payment link generation) and **Orders API** (order management).
> RideXpress will NOT store sensitive user financial information — payment processing is fully delegated to Square.

- [ ] Create Mule 4 project `square-system-api/`
- [ ] Implement endpoints per existing RAML spec:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `POST /payment-link` | 🔲 To implement | Square Checkout API — create payment link |
| 2 | `GET /orders/{orderId}` | 🔲 To implement | Square Orders API — get order |
| 3 | `PUT /orders/{orderId}` | 🔲 To implement | Square Orders API — update order fulfillment |

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
| 3 | `POST /cases` | 🔲 To implement | Salesforce REST API — create Case (support) |
| 4 | `POST /rides` | 🔲 To implement | Salesforce REST API — create custom Ride record for analytics |

### 4.5 Email System API (`email-system-api`)

> Provides email sending functionality (welcome emails, ride receipts, verification codes).

- [ ] Create Mule 4 project `email-system-api/`
- [ ] Define full RAML spec (currently a stub)
- [ ] Implement endpoints:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `POST /send` | 🔲 To implement | Gmail API or SMTP — send email |
| 2 | `POST /send/template` | 🔲 To implement | Send templated email (welcome, ride receipt, etc.) |

### 4.6 Push Notifications System API (`push-notifications-system-api`)

> Provides notifications functionality with drivers and passengers.

- [ ] Create Mule 4 project `push-notifications-system-api/`
- [ ] Define full RAML spec (currently a stub)
- [ ] Implement endpoints:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `POST /notify` | 🔲 To implement | APNs HTTP/2 API — send push notification |
| 2 | `POST /notify/batch` | 🔲 To implement | APNs — send batch notifications |

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
| **P0** | 2 | Database System API — Users CRUD | UC-1, UC-2 | Foundation for all user operations |
| **P0** | 2 | Database System API — Rides CRUD | UC-2, UC-3 | Foundation for all ride operations |
| **P1** | 1 | Experience API — `POST /user` (via user-sign-up) | UC-1 | Core user registration flow |
| **P1** | 1 | Experience API — `POST /rides` (via request-ride) | UC-2 | Core ride request flow |
| **P1** | 3 | User Sign Up Process API | UC-1 | Orchestrates user creation |
| **P1** | 3 | Request Ride Process API | UC-2 | Orchestrates ride lifecycle |
| **P2** | 1 | Experience API — remaining ride endpoints | UC-3, UC-4, UC-5 | Ride tracking features |
| **P2** | 4 | Okta System API | UC-1 | Authentication & authorization |
| **P2** | 4 | Google Maps System API | UC-2, UC-4 | Location search and routing |
| **P2** | 4 | Square System API | UC-2, UC-5 | Payment processing |
| **P3** | 3 | Accept Ride Process API | UC-3 | Ride acceptance lifecycle |
| **P3** | 3 | Waiting Ride Process API | UC-4 | Driver tracking and ETA |
| **P3** | 3 | Finish Ride Process API | UC-5 | Ride completion, payment confirmation |
| **P3** | 4 | Salesforce / Email / Push Notifications System APIs | UC-1, UC-5 | Analytics, notifications |
| **P3** | 5 | Cross-cutting: MUnit tests, security, observability | All | Quality & production readiness |
| **P4** | 5 | CI/CD Pipelines (4 pipelines) | All | Automated build, deploy, release |

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
