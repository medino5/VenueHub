# Changelog

## 1.0.10+11 - 2026-05-28

- Replaced the in-app logo asset and Android launcher icon with the updated VenueHub logo.
- Removed non-functional venue detail share controls and “New”/superhost wording from venue presentation.
- Tightened venue offers, added matching offer icons, and made host listing offers selectable.
- Improved the demo Leyte map preview, golden review stars, login quick-demo cards, and profile details layout.
- Rebuilt the Android release APK with the deployed Render API URL.

## 1.0.9+10 - 2026-05-17

- Reduced the oversized direct venue cards with shorter image banners.
- Added amenity/facility icon highlights to direct venue cards.
- Restored the profile page closer to the older layout with a centered avatar and obvious logout button.
- Rebuilt the Android release APK with the deployed Render API URL.

## 1.0.8+9 - 2026-05-17

- Renamed the customer bottom tab from Trips to Bookings.
- Cleaned up the login screen while keeping quick demo account chips for school presentations.
- Restored sideways venue sections inside the current Explore layout so users can scroll down and sideways.
- Expanded the demo seed data with more Region 8 event venues across Leyte, Samar, Biliran, and Southern Leyte.
- Rebuilt the Android release APK with the deployed Render API URL.

## 1.0.7+8 - 2026-05-17

- Forced the client APK to use the light theme for a clean demo presentation.
- Restored a brighter VenueHub white, blue, and gold palette so actions, icons, and tabs are easier to read.
- Rebuilt the Android release APK with the deployed Render API URL.

## 1.0.6+7 - 2026-05-17

- Replaced decorative venue-type categories with Eastern Visayas location filters.
- Added a customer Favourites tab backed by saved local heart selections.
- Restored the VenueHub navy/blue palette while keeping the premium Airbnb-inspired layout and animations.
- Rebuilt the Android release APK with the deployed Render API URL.

## 1.0.5+6 - 2026-05-17

- Redesigned the customer Explore, Venue Details, Trips, and Profile screens with an Airbnb-inspired white editorial theme and Rausch CTA color.
- Added centralized Flutter theme tokens, Google Fonts typography, reusable search/category/price/status/sticky booking widgets, and dark-mode semantic colors.
- Upgraded venue cards with square image carousels, animated dots, guest-favorite badges, heart bounce feedback, and Hero transitions into venue details.
- Updated booking cards to the Trips wording with Upcoming/Past/Cancelled tabs and compact horizontal cards.
- Rebuilt the Android release APK with the deployed Render API URL.

## 1.0.4+5 - 2026-05-04

- Fixed venue image handling to support API `imageUrl` values and cleaner placeholders.
- Added venue details demo map previews, profile no-refund policy, and editable profile preferences/likes/dislikes/notes.
- Added backend notifications for booking status/payment updates with a customer notification bell.
- Improved host/admin venue filtering, admin user filtering/detail views, dashboard stats, income charts, and confirmed service-fee changes.
- Added backend notification and platform setting migrations.

## 1.0.3+4 - 2026-05-03

- Limited the customer location category scope to Eastern Visayas places only.
- Replaced seed venues with temporary Eastern Visayas demo venues across Leyte, Samar, and Eastern Samar.
- Kept Packages and Services visible as inactive/blank demo tabs for now.

## 1.0.2+3 - 2026-05-03

- Refined the customer explore screen with an Airbnb-inspired floating search pill, animated tabs, horizontal location categories, and side-scroll venue sections.
- Added saved profile editing with gallery-based profile photo upload, editable name, phone, and gender fields.
- Added a protected backend profile update endpoint for account detail changes.

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
