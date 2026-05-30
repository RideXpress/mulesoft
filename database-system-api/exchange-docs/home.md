# Database System API

The Database System API encapsulates all PostgreSQL operations for the RideXpress platform. It is the single point of access for the database and provides a clean REST API over the RideXpress database schema.

## Overview

This System API provides CRUD operations to store non-sensitive information in the database, following the API-led connectivity architecture pattern.

## Endpoints

### Users
- `POST /users` — Create a new user
- `GET /users` — List all users
- `GET /users/{id}` — Get user by ID
- `PATCH /users/{id}` — Update user by ID
- `GET /users/{id}/location` — Get user's latest location
- `POST /users/{id}/location` — Post user's real-time location
- `POST /users/{id}/feedback` — Submit feedback for a user
- `GET /users/{id}/vehicles` — Get user's vehicles
- `POST /users/{id}/vehicles` — Add a vehicle for a user
- `PUT /users/{id}/vehicles/{vehicleId}` — Update a vehicle

### Rides
- `POST /rides` — Create a new ride
- `GET /ride/{id}` — Get ride by ID
- `PATCH /ride/{id}` — Update a ride
- `POST /ride/{id}/feedback` — Submit ride feedback

### Drivers
- `GET /drivers` — List available drivers
- `GET /drivers/{id}` — Get driver by ID
- `POST /drivers/{id}` — Create driver record
- `PATCH /drivers/{id}` — Update driver record
- `POST /drivers/{id}/vehicles` — Register driver vehicle
- `POST /drivers/{id}/documents` — Upload driver documents
- `POST /drivers/{id}/banking` — Store driver banking info
- `POST /drivers/{id}/earnings` — Record driver earnings
- `GET /drivers/{id}/earnings` — Get driver earnings history
- `POST /drivers/{id}/payouts` — Create driver payout
- `PATCH /drivers/{id}/payouts/{payoutId}` — Update payout status
- `GET /drivers/payouts/pending` — Get drivers eligible for payout

### Payments
- `GET /payments/{ride_id}` — Get payment by ride ID
- `PATCH /payments/{payment_id}` — Update payment status

### Pricing
- `GET /pricing` — Get current pricing configuration
- `GET /pricing/surge` — Get surge zone pricing
- `GET /ride-types` — Get available ride types
