# Copilot Instructions for RideXpress MuleSoft Repository

## Overview

This repository contains MuleSoft Mule applications for the RideXpress platform, including the **RideXpress Experience API** (primary project) and supporting modules. The Experience API is a REST API that orchestrates interactions with multiple backend systems (Okta, Google Maps, Square, RabbitMQ, and various system APIs).

## Build, Test, and Lint Commands

### Building the Project

```bash
cd ridexpress-experience-api
mvn clean package
```

**What this does:**
- Compiles the Mule application
- Generates the deployable JAR file in `target/`
- Produces a Mule deployable (`target/ridexpress-experience-api-1.0.0-SNAPSHOT-mule-application.jar`)

### Running Tests

```bash
# Run all MUnit tests
mvn clean test

# Run a single test file
mvn test -Dtest=riders-test

# Run with test coverage report
mvn clean test -Dmunit.coverage.runCoverage=true
```

**Important:** 
- Test suite uses `test-secrets.properties` (JVM arg: `-Dsecrets.path=test-secrets.properties`)
- MUnit 3.7.0 runtime is Mule 4.10.0
- Tests mock external connectors (HTTP requests to Okta, Google Maps, Square, system APIs) using `munit-tools:mock-when`
- DB and AMQP calls are mocked to avoid external dependencies
- Coverage reports generate in `target/site/munit/coverage/`

### Validation

```bash
# Validate the mule-artifact.json structure
mvn validate
```

## High-Level Architecture

### Core Structure

The Experience API follows a **modular flow-based architecture**:

1. **Main Entry Point** (`ridexpress-experience-api.xml`)
   - APIKit router configuration exposes REST endpoints via RAML (`api/ridexpress-experience-api.raml`)
   - HTTP listener on port 8081
   - Central error handler for consistent error responses

2. **Configuration** (`config.xml`)
   - HTTP request connectors to external systems: Okta (auth), Google Maps (geolocation), Square (payments), Salesforce (support cases)
   - System API connectors: Database, User Sign-Up Process, Request/Cancel Ride Process, Driver Availability Process
   - AMQP/RabbitMQ configuration for async messaging
   - Properties loaded from `config.properties` and environment-specific `test-secrets.properties`

3. **Domain Flows** (separate XML files)
   - **`users.xml`**: User management and authentication flows
   - **`users-profile.xml`**: User profile operations (retrieve, update profile data)
   - **`drivers.xml`**: Driver management, availability, and rating flows
   - **`geolocations.xml`**: Geolocation services using Google Maps API
   - **`rides.xml`**: Core ride lifecycle (request, track, complete, rating)
   - **`support.xml`**: Support ticket management integration with Salesforce
   - **`auth.xml`**: OAuth/token validation with Okta
   - **`db-operations-impl.xml`**: Reusable database operation subflows

### Data Flow Patterns

- **Request → Validation → Transform → External Call → Response Transform**
- External service calls are wrapped in error handling with appropriate HTTP status codes
- Async operations use RabbitMQ for decoupled processing (e.g., ride events)
- Database interactions use prepared statements with parameterized queries

### External Dependencies

| System | Purpose | Config Reference |
|--------|---------|------------------|
| Okta | Authentication & authorization | `okta` request-config |
| Google Maps | Geolocation & distance calculations | `google-maps` request-config |
| Square | Payment processing | `square` request-config |
| RabbitMQ | Async event messaging | `rabbitmq` AMQP config |
| Database System API | Persistent storage operations | `database-system-api` request-config |
| Salesforce System API | Support case management | `salesforce-system-api` request-config |

## Key Conventions

### File Organization

- **Flows**: `src/main/mule/*.xml` — One domain per file
- **Tests**: `src/test/munit/*.xml` — Mirrors domain structure (e.g., `users-test.xml` tests `users.xml`)
- **API Specs**: `src/main/resources/api/` — RAML definitions and shared data types from Anypoint Exchange
- **Config**: `src/main/resources/` — Externalized properties and logging configuration
- **Resources**: Exchange modules at `src/main/resources/api/exchange_modules/` — Shared data types (User, Ride, etc.) and OAuth security scheme

### Naming Conventions

- **Flows**: kebab-case (e.g., `get-user-profile`, `post-support-tickets`)
- **Subflows**: Prefixed with `impl-` for implementation detail (e.g., `impl-validate-token`)
- **Variables**: camelCase (e.g., `currentUserId`, `requestPayload`)
- **HTTP request configs**: Service name pattern (e.g., `google-maps`, `database-system-api`)

### Error Handling

- All flows use `error-handler` with specific error type matching (e.g., `APIKIT:NOT_FOUND`, `HTTP:TIMEOUT`)
- Standard error responses set `vars.httpStatus` and return JSON: `{message: "error description"}`
- Third-party API errors are caught and transformed to user-friendly responses

### Transform/DataWeave

- All message transformations use `ee:transform` with DataWeave 2.0
- Payload transformations set both `payload` and `variables` when needed
- Reusable transform logic goes in dedicated subflows (not inline in flows)

### Testing Patterns (MUnit)

- Each domain has a corresponding `-test.xml` file with `munit:config` and multiple `munit:test` declarations
- Mock setup in `munit:behavior` section using `munit-tools:mock-when`
- Assertions use `munit-tools:assert-equals`, `munit-tools:assert-null`, etc.
- Test secrets and mock responses are defined inline or from test resources
- Never test external service integrations directly; mock all HTTP requests

### Configuration & Secrets

- Runtime requires Java 17 (from `mule-artifact.json`)
- Minimum Mule Runtime: 4.9.0
- Externalize configuration via `configuration-properties`:
  - `config.properties` — Non-sensitive defaults
  - `test-secrets.properties` — Test credentials (not committed)
  - Environment variables for production secrets
- Property keys follow pattern: `{system}.{property}` (e.g., `okta.hostname`, `rabbitmq.port`)

### Dependencies

- **Core**: Mule Runtime 4.10.0 with standard modules
- **Connectors**: APIKit 1.11.5, HTTP 1.10.3, AMQP 1.8.2
- **Testing**: MUnit 3.7.0 with munit-runner and munit-tools
- **Repositories**: 
  - Anypoint Exchange (private org)
  - MuleSoft public releases
  - MuleSoft Enterprise repository (for EE features/BOM)

## Troubleshooting

### Common Issues

1. **Build fails with Maven repository error**
   - Ensure `settings.xml` has credentials for Anypoint Exchange and MuleSoft Enterprise repo
   - The Enterprise repo requires separate Nexus EE credentials from MuleSoft Support (not Connected App credentials)

2. **Tests fail with undefined properties**
   - Verify `test-secrets.properties` exists in `src/test/resources/`
   - Check that `-Dsecrets.path=test-secrets.properties` JVM argument is set (automatically handled by munit-maven-plugin)

3. **Mock not intercepting requests**
   - Ensure mock-when is configured before the flow invocation in test behavior
   - Verify the processor path matches exactly (e.g., `http:request` with correct config-ref)

## Related Documentation

- **RAML API Spec**: `src/main/resources/api/ridexpress-experience-api.raml`
- **Parent Repository**: [RideXpress/docs](https://github.com/RideXpress/docs)
- **MuleSoft Runtime**: Mule 4.10.0 with Java 17
