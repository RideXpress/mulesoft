# RideXpress - MuleSoft Implementation Plan

> **Monorepo** for all RideXpress MuleSoft API implementations following **API-led connectivity** architecture.
>
> _Last updated: March 2026_

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Phase 1 — Experience API (ridexpress-experience-api)](#phase-1--experience-api-ridexpress-experience-api)
- [Phase 2 — Database System API (db-system-api)](#phase-2--database-system-api-db-system-api)
- [Phase 3 — Process APIs](#phase-3--process-apis)
- [Phase 4 — System APIs (External Integrations)](#phase-4--system-apis-external-integrations)
- [Phase 5 — Cross-Cutting Concerns](#phase-5--cross-cutting-concerns)
- [Database Schema](#database-schema)
- [Integration Infrastructure](#integration-infrastructure)
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

---

## Repository Structure

```
mulesoft/                              # Monorepo root
├── IMPLEMENTATION_PLAN.md             # This file — track progress here
├── README.md                          # Project overview
├── design-center/                     # RAML API specs (synced with Anypoint Design Center)
│   ├── ridexpress-experience-api/     # Experience API spec
│   ├── db-system-api/                 # Database System API spec
│   ├── request-ride-process-api/      # Request Ride Process API spec
│   ├── okta-system-api/               # Okta System API spec (stub)
│   ├── google-maps-system-api/        # Google Maps System API spec (stub)
│   ├── square-system-api/             # Square System API spec
│   ├── salesforce-system-api/         # Salesforce System API spec (stub)
│   ├── gmail-system-api/              # Gmail System API spec (stub)
│   ├── apple-push-notifications.../   # Apple Push Notifications spec (stub)
│   ├── common-data-types-library/     # Shared data types
│   ├── user-data-type/                # User data type definition
│   ├── ride-data-type/                # Ride data type definition
│   └── ...                            # Traits, security schemes, resource types
├── ridexpress-experience-api/         # ✅ Experience API implementation
├── rides-process-async-api/           # ✅ Async ride processing (RabbitMQ consumer)
├── db-system-api/                     # 🔲 To be created — Database System API
├── user-sign-up-process-api/          # 🔲 To be created — User Sign Up Process API
├── request-ride-process-api/          # 🔲 To be created — Request Ride Process API
├── accept-ride-process-api/           # 🔲 To be created — Accept Ride Process API
├── waiting-ride-process-api/          # 🔲 To be created — Waiting Ride Process API
├── finish-ride-process-api/           # 🔲 To be created — Finish Ride Process API
├── okta-system-api/                   # 🔲 To be created — Okta integration
├── google-maps-system-api/            # 🔲 To be created — Google Maps integration
├── square-system-api/                 # 🔲 To be created — Square payments integration
├── salesforce-system-api/             # 🔲 To be created — Salesforce CRM integration
├── gmail-system-api/                  # 🔲 To be created — Gmail notification integration
├── apple-push-notifications.../       # 🔲 To be created — Apple push notifications
└── util/                              # Maven settings & utility files
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
| 2 | `GET /user` | `get:\user:router` | 🟡 Partial | Calls `get-user-by-id-impl` sub-flow (direct DB query). Should call **db-system-api** instead |
| 3 | `PUT /user` | `put:\user:router` | 🔲 Stub only | Call **db-system-api** `PATCH /users/{id}` to update user record |
| 4 | `DELETE /user` | `delete:\user:router` | 🔲 Stub only | Call **db-system-api** to soft-delete (deactivate) user |
| 5 | `GET /user/vehicles` | `get:\user\vehicles:router` | 🔲 Stub only | Call **db-system-api** to retrieve driver's vehicles |
| 6 | `PUT /user/vehicles/{id}` | `put:\user\vehicles\(id):router` | 🔲 Stub only | Call **db-system-api** to update active vehicle |
| 7 | `POST /user/geolocation` | `post:\user\geolocation:router` | 🔲 Stub only | Call **db-system-api** `POST /users/{id}/location` to post real-time location |
| 8 | `POST /user/attachments` | `post:\user\attachments:router` | 🔲 Stub only | Store file (S3/object storage) — may need a new system API or direct connector |

### 1.2 Rides Endpoints (`/rides`)

| # | Endpoint | Flow Name | Status | Notes |
|---|----------|-----------|--------|-------|
| 9 | `GET /rides` | `get:\rides:router` | 🟡 Partial | Calls `get-rides-impl` sub-flow (direct DB query). Should call **db-system-api** instead |
| 10 | `POST /rides` | `post:\rides:router` | 🟡 Partial | Publishes to RabbitMQ. Should include DataWeave transformation and call **request-ride-process-api** |
| 11 | `GET /rides/{id}` | `get:\rides\(id):router` | 🔲 Stub only | Call **db-system-api** `GET /ride/{id}` |
| 12 | `GET /rides/{id}/passenger` | `get:\rides\(id)\passenger:router` | 🔲 Stub only | Call **db-system-api** to get passenger details for ride |
| 13 | `GET /rides/{id}/passenger/location` | `get:\rides\(id)\passenger\location:router` | 🔲 Stub only | Call **db-system-api** `GET /users/{passengerId}/location` |
| 14 | `GET /rides/{id}/driver` | `get:\rides\(id)\driver:router` | 🔲 Stub only | Call **db-system-api** to get driver details for ride |
| 15 | `GET /rides/{id}/driver/location` | `get:\rides\(id)\driver\location:router` | 🔲 Stub only | Call **db-system-api** `GET /users/{driverId}/location` + compute arrival time |
| 16 | `GET /rides/{id}/payment` | `get:\rides\(id)\payment:router` | 🔲 Stub only | Call **square-system-api** to retrieve payment status |
| 17 | `GET /rides/{id}/route` | `get:\rides\(id)\route:router` | 🔲 Stub only | Call **google-maps-system-api** for route details |
| 18 | `POST /rides/{id}/feedback` | `post:\rides\(id)\feedback:router` | 🟡 Partial | Publishes to RabbitMQ. Should transform payload and include ride ID |
| 19 | `GET /rides/{id}/status` | `get:\rides\(id)\status:router` | 🔲 Stub only | Call **db-system-api** `GET /ride/{id}` and extract status + arrival time |
| 20 | `PUT /rides/{id}/status` | `put:\rides\(id)\status:router` | 🔲 Stub only | Call **db-system-api** `PATCH /ride/{id}` to update status |
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
> These should be refactored to call the **db-system-api** via HTTP instead.

- [ ] Refactor `get-rides-impl` sub-flow to call `db-system-api` HTTP endpoint instead of direct DB query
- [ ] Refactor `get-user-by-id-impl` sub-flow to call `db-system-api` HTTP endpoint instead of direct DB query
- [ ] Remove PostgreSQL dependency from Experience API `pom.xml` after refactoring
- [ ] Remove `db:config` from Experience API `config.xml` after refactoring

---

## Phase 2 — Database System API (`db-system-api`)

> The Database System API encapsulates all PostgreSQL operations. It is the single point of access for
> the database and provides a clean REST API over the RideXpress database schema.

### 2.1 Project Setup

- [ ] Create Mule 4 project `db-system-api/` with standard structure
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
  2. Call **db-system-api** `POST /users` to create user record
  3. Call **okta-system-api** to create Okta user account
  4. Call **gmail-system-api** to send welcome email
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
  3. Update ride status (`DRIVING_TO_PASSENGER_LOCATION` → `WAITING_FOR_PASSANGER`)
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

### 4.1 Okta System API (`okta-system-api`)

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

- [ ] Create Mule 4 project `square-system-api/`
- [ ] Implement endpoints per existing RAML spec:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `POST /payment-links` | 🔲 To implement | Square Checkout API — create payment link |
| 2 | `GET /orders/{orderId}` | 🔲 To implement | Square Orders API — get order |
| 3 | `PUT /orders/{orderId}` | 🔲 To implement | Square Orders API — update order fulfillment |
| 4 | `POST /refunds` | 🔲 To implement | Square Refunds API — process refund |

### 4.4 Salesforce System API (`salesforce-system-api`)

- [ ] Create Mule 4 project `salesforce-system-api/`
- [ ] Define full RAML spec (currently a stub)
- [ ] Implement endpoints:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `POST /contacts` | 🔲 To implement | Salesforce REST API — create Contact |
| 2 | `PUT /contacts/{id}` | 🔲 To implement | Salesforce REST API — update Contact |
| 3 | `POST /cases` | 🔲 To implement | Salesforce REST API — create Case (support) |
| 4 | `POST /rides` | 🔲 To implement | Salesforce REST API — create custom Ride record for analytics |

### 4.5 Gmail System API (`gmail-system-api`)

- [ ] Create Mule 4 project `gmail-system-api/`
- [ ] Define full RAML spec (currently a stub)
- [ ] Implement endpoints:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `POST /send` | 🔲 To implement | Gmail API or SMTP — send email |
| 2 | `POST /send/template` | 🔲 To implement | Send templated email (welcome, ride receipt, etc.) |

### 4.6 Apple Push Notifications System API (`apple-push-notifications-system-api`)

- [ ] Create Mule 4 project `apple-push-notifications-system-api/`
- [ ] Define full RAML spec (currently a stub)
- [ ] Implement endpoints:

| # | Endpoint | Status | External Call |
|---|----------|--------|---------------|
| 1 | `POST /notify` | 🔲 To implement | APNs HTTP/2 API — send push notification |
| 2 | `POST /notify/batch` | 🔲 To implement | APNs — send batch notifications |

---

## Phase 5 — Cross-Cutting Concerns

### 5.1 Error Handling Strategy

- [ ] Implement consistent error handling across all APIs using the `error-responses-trait`
- [ ] Standard error response format: `{ "message": "...", "correlationId": "..." }`
- [ ] Error codes: 400, 401, 403, 404, 405, 408, 409, 413, 429, 500
- [ ] Dead-letter queue for failed async messages
- [ ] Retry policies for transient failures (HTTP 503, connection timeouts)

### 5.2 Security

- [ ] OAuth 2.0 token validation on Experience API using Okta
- [ ] Client Credentials enforcement on Process & System APIs
- [ ] Secure properties encryption for all sensitive configuration (passwords, API keys)
- [ ] TLS configuration for all HTTP listeners
- [ ] API policies: rate limiting, IP whitelisting (API Manager)

### 5.3 Observability

- [ ] Correlation ID (`X-Transaction-Id`) propagation across all API layers
- [ ] Structured logging with correlation IDs in all flows
- [ ] Anypoint Monitoring dashboards
- [ ] Custom alerts for error rates and latency

### 5.4 Testing (MUnit)

- [ ] Add MUnit tests for each Experience API flow
- [ ] Add MUnit tests for each DB System API flow
- [ ] Add MUnit tests for each Process API flow
- [ ] Mock external services in System API tests
- [ ] Target: >80% code coverage per project

### 5.5 CI/CD

- [ ] GitHub Actions workflow for building each project on PR
- [ ] Automated MUnit test execution
- [ ] Deployment to CloudHub/Runtime Fabric
- [ ] Environment-specific property management (dev, staging, production)

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

## Conventions & Best Practices

### Project Naming

- **Experience APIs**: `{name}-experience-api`
- **Process APIs**: `{name}-process-api`
- **System APIs**: `{name}-system-api`

### Flow Naming

- APIKit-generated flows: `{method}:\{resource}:router`
- Implementation sub-flows: `{operation}-{entity}-impl` (e.g., `get-rides-impl`)
- Error handler flows: `global-error-handler`

### Configuration

- All environment-specific values externalized to `config.properties`
- Sensitive values use `${ext.*}` pattern pointing to secure properties file
- Secret file path configured via `-Dsecrets.path` JVM argument

### HTTP Request Configuration

Each downstream API connection should be defined as an `http:request-config` with:
- Externalized `host`, `port`, `basePath` in properties
- Response timeout configuration
- Connection idle timeout

### DataWeave

- Use DataWeave 2.0 for all transformations
- Separate transformation modules in `src/main/resources/dw/` for reusable scripts
- Follow consistent naming: `{source}-to-{target}.dwl`

### Error Handling

- Global error handler in the main API flow for APIKit errors
- Per-flow error handlers for downstream call failures
- Standard error response: `{ "message": "...", "correlationId": "..." }`
- Map HTTP error codes from downstream APIs appropriately

### Logging

- Always log at flow entry with `level="INFO"`
- Log payload at `level="DEBUG"` only (not INFO, to avoid PII in production)
- Include `#[correlationId]` in all log messages
- Use rolling file appender with 10 MB limit, max 10 files

---

## Priority Order

| Priority | Phase | Item | Justification |
|----------|-------|------|---------------|
| **P0** | 2 | DB System API — Users CRUD | Foundation for all user operations |
| **P0** | 2 | DB System API — Rides CRUD | Foundation for all ride operations |
| **P1** | 1 | Experience API — `POST /user` (via user-sign-up) | Core user registration flow |
| **P1** | 1 | Experience API — `POST /rides` (via request-ride) | Core ride request flow |
| **P1** | 3 | User Sign Up Process API | Orchestrates user creation |
| **P1** | 3 | Request Ride Process API | Orchestrates ride lifecycle |
| **P2** | 1 | Experience API — remaining ride endpoints | Ride tracking features |
| **P2** | 4 | Okta System API | Authentication & authorization |
| **P2** | 4 | Google Maps System API | Location search and routing |
| **P2** | 4 | Square System API | Payment processing |
| **P3** | 3 | Accept / Waiting / Finish Ride Process APIs | Complete ride lifecycle |
| **P3** | 4 | Salesforce / Gmail / Apple Push System APIs | Analytics, notifications |
| **P3** | 5 | Cross-cutting: MUnit tests, security, observability | Quality & production readiness |
