# VenueHub Backend

Node.js, Express, Prisma, PostgreSQL, JWT, and simulated payment logic for VenueHub.

## Local Setup

```bash
npm install
copy .env.example .env
npx prisma generate
npx prisma migrate deploy
npx prisma db seed
npm run dev
```

## Scripts

```text
npm start           Start production server
npm run dev         Start nodemon dev server
npm run prisma:seed Seed demo users, venues, booking, payment, receipt
npm run prisma:deploy Apply migrations
```

## API Routes

```text
POST /api/auth/register
POST /api/auth/login
GET  /api/auth/me

GET    /api/venues
GET    /api/venues/:id
GET    /api/venues/search?query=&location=
GET    /api/venues/host/my
POST   /api/venues
PUT    /api/venues/:id
DELETE /api/venues/:id

POST /api/bookings
GET  /api/bookings/my
GET  /api/bookings/host
GET  /api/bookings/host/income
PUT  /api/bookings/:id/status

POST /api/payments/simulate
GET  /api/payments/:bookingId

POST /api/reviews
GET  /api/reviews/venue/:venueId

GET /api/admin/dashboard
GET /api/admin/users
GET /api/admin/hosts
GET /api/admin/venues
GET /api/admin/bookings
GET /api/admin/income-summary
```

## Render

Root repository build:

```bash
cd backend && npm install && npx prisma generate && npx prisma migrate deploy
```

Root repository start:

```bash
cd backend && npm start
```
