# Changelog

## Backend email API hotfix - 2026-05-03

- Added Brevo transactional email API support for Render Free deployments where SMTP ports time out.
- Documented the no-domain Brevo setup path for demo email delivery.

## Backend email hotfix - 2026-05-03

- Gmail app passwords are now sanitized by removing accidental spaces from `SMTP_PASS`.
- SMTP email sending now uses a 10-second timeout so the app returns a clear error instead of loading too long.
- Added clearer SMTP error messages for login failures and connection timeouts.

## 1.0.1+2 - 2026-05-03

- Fixed email handling so password reset clearly reports missing provider setup instead of silently skipping emails.
- Added optional Resend email support alongside SMTP for easier Render deployment.
- Added receipt email delivery status to the in-app receipt screen.
- Added confirmation dialogs and success messages for booking and venue approve/reject/complete actions.
- Cleaned the login screen by removing duplicate VenueHub text, marketing copy, and the API URL debug label.
- Rebuilt the Android release APK with the deployed Render API URL.

## 1.0.0+1 - Initial demo build

- First client demo APK with customer, host, and admin booking flows.
