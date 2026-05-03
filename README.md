# VenueHub

VenueHub is a full-stack event venue booking prototype with a Node.js/Express API, Prisma, Supabase PostgreSQL, JWT auth, simulated payments, and a Flutter Android app.

## Project Structure

```text
backend/  Node.js + Express + Prisma API
mobile/   Flutter Android app
```

## Demo Accounts

After seeding the database, use these accounts:

```text
customer@venuehub.test  password123
host@venuehub.test      password123
admin@venuehub.test     password123
```

## 1. Build Backend Locally

```bash
cd backend
npm install
copy .env.example .env
```

Edit `backend/.env` and set:

```text
DATABASE_URL="your Supabase PostgreSQL connection string"
JWT_SECRET="a long random secret"
PORT=5000
```

Then run:

```bash
npx prisma generate
npx prisma migrate deploy
npx prisma db seed
npm run dev
```

The API should be available at:

```text
http://localhost:5000/api/health
```

## 2. Push Backend To GitHub

Create a GitHub repository and push this project. Render will connect to this repository.

## 3. Create Supabase Database

Create a Supabase project, open Project Settings, copy the PostgreSQL connection string, and use it as `DATABASE_URL`.

For this project, the direct Supabase database URL pattern is:

```text
postgresql://postgres:[YOUR-PASSWORD]@db.uxoggpvmlyvbepkiydqs.supabase.co:5432/postgres?schema=public
```

Replace `[YOUR-PASSWORD]` with the database password from Supabase. Do not commit the real password to GitHub.

If Supabase says `Not IPv4 compatible`, use the Supabase **Session Pooler** connection string for Render instead of the direct `db.uxoggpvmlyvbepkiydqs.supabase.co` host. Copy it from Supabase `Project Settings > Database > Connection Pooling` and keep `?schema=public` at the end for Prisma.

Make sure the password is URL-encoded if it contains special characters.

Important: the Supabase prompt for `@supabase/supabase-js`, `@supabase/ssr`, `page.tsx`, and `utils/supabase/*` is for Next.js apps that use Supabase Auth. VenueHub does not need those files because it uses:

```text
Flutter app -> Express API -> Prisma -> Supabase PostgreSQL
```

For this prototype, Supabase is only the PostgreSQL database. Authentication is handled by the Express API with bcrypt and JWT.

Supabase values you need:

```text
DATABASE_URL=Supabase PostgreSQL connection string
```

Supabase values you do not need for this version:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
@supabase/supabase-js
@supabase/ssr
Next.js middleware files
```

## 4. Add DATABASE_URL To Render

Create a Render Web Service from the GitHub repository.

Environment variables:

```text
DATABASE_URL=your Supabase PostgreSQL URL
JWT_SECRET=your long random secret
JWT_EXPIRES_IN=7d
CLIENT_ORIGIN=*
APP_BASE_URL=https://your-render-service.onrender.com
SMTP_HOST=your SMTP host
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your SMTP username
SMTP_PASS=your SMTP password
SMTP_FROM=VenueHub <no-reply@yourdomain.com>
RESEND_API_KEY=optional Resend API key instead of SMTP
```

Email is used for password reset and booking/payment receipt emails. Configure either SMTP variables or `RESEND_API_KEY` in Render. If no email provider is configured, password reset will show a clear setup error instead of pretending the email was sent.

For the quickest client demo email setup, use Resend:

```text
RESEND_API_KEY=your_resend_api_key
SMTP_FROM=VenueHub <onboarding@resend.dev>
```

If you use your own sender domain, verify that domain in Resend first, then replace `SMTP_FROM` with your verified sender address.

## 5. Deploy Backend On Render

If the Render root is the repository root, use:

```bash
Build Command: cd backend && npm install && npx prisma generate && npx prisma migrate deploy
Start Command: cd backend && npm start
```

If the Render root is `backend/`, use:

```bash
Build Command: npm install && npx prisma generate && npx prisma migrate deploy
Start Command: npm start
```

After the first successful deploy, seed demo data from a local machine connected to the same Supabase `DATABASE_URL`:

```bash
cd backend
npx prisma db seed
```

## 6. Put Render API URL Inside Flutter

For local Android emulator testing, the app defaults to:

```text
http://10.0.2.2:5000/api
```

For a deployed backend, pass the Render URL at build time:

```bash
cd mobile
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://your-render-service.onrender.com/api
```

## 7. Build APK

The release APK will be created under:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

The latest APK is also copied into the repository at:

```text
releases/VenueHub-release.apk
```

Whenever that file is pushed to `main`, GitHub Actions publishes or updates the `VenueHub Latest APK` release so the APK can be downloaded from GitHub Releases.

Download the latest APK here:

```text
https://github.com/medino5/VenueHub/releases/tag/venuehub-latest
```

## 8. Client Installs APK And Tests With Internet

Install the APK on an Android phone. The phone must have internet access because the app connects to Render, and Render connects to Supabase.

## Payment Rules

- Demo payment only, no Stripe.
- Booking requires a 50% non-refundable security deposit.
- Remaining 50% balance is due before or on event day.
- VenueHub service fee is 10%.
- Simulated payment creates payment and receipt records.

## Client Turnover Checklist

- Backend deployed on Render and connected to Supabase through `DATABASE_URL`.
- Render environment variables include JWT and SMTP settings.
- Supabase migrations are applied through Render build command.
- Demo accounts are seeded with `npx prisma db seed`.
- Latest APK is available from GitHub Releases.
- Mobile APK is built with `--dart-define=API_BASE_URL=https://your-render-service.onrender.com/api`.

## Common Troubleshooting

- If login says host lookup or network error, confirm the APK was built with the Render API URL and Android internet permission is present.
- If Render cannot reach Supabase, use the Supabase Session Pooler URL, not the direct database host.
- If password reset emails do not arrive, verify SMTP or Resend variables in Render, redeploy the backend, and check Render logs.
- If demo accounts do not work, run `npx prisma db seed` against the deployed Supabase database.

## Version Tracking

The Flutter app version is tracked in `mobile/pubspec.yaml`, and release notes are tracked in `CHANGELOG.md`. Whenever a new APK is built for the client, bump the version before committing so GitHub history and APK builds stay traceable.
