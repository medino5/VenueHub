# Changelog

## 1.0.22+23 - 2026-06-01

- Removed leftover host approval/deposit-awaiting wording from the current direct-booking flow and changed host metrics to upcoming reserved bookings.
- Hid customer profile preferences and likes from the customer's own booking detail screen while keeping them visible for host/admin review.
- Scoped favourites to each signed-in customer account so one customer's liked venues no longer appear on another account.

## 1.0.21+22 - 2026-06-01

- Clarified the host dashboard income wording so paid received, estimated payout, service fee, and unpaid balances are explicitly scoped to the signed-in host's venues.
- Improved host metric card layout so large peso amounts stay on one line instead of wrapping or getting cut off.
- Added a short host income explanation card for client/demo clarity.

## 1.0.20+21 - 2026-06-01

- Removed the customer Cancelled tab and grouped closed, rejected, and older bookings under History.
- Removed the admin dashboard unpaid-bookings card so admin metrics stay focused on oversight and income visibility.
- Kept the income chart titled Platform fee trend while showing historical-style monthly bars with the current month tied to live platform-fee data.

## 1.0.19+20 - 2026-06-01

- Removed the host-approval requirement from the normal customer booking flow so available dates can go straight to 50% deposit payment.
- Added venue unavailable-date checks so already-booked dates are disabled in the booking calendar and double-booking is blocked server-side by date range.
- Updated host/admin wording from approval-focused booking requests to deposit and unpaid-balance states.

## 1.0.18+19 - 2026-05-31

- Clarified admin income wording by renaming receivables to unpaid balances and explaining what that amount means.
- Replaced repeated fallback income bars with a month/year trend and a labeled demo trend when live history only exists in one month.
- Improved admin venue listing actions so pending venues show approve/reject, approved venues show unlist, and rejected venues show restore.

## 1.0.17+18 - 2026-05-31

- Tightened booking status rules so payments open only after host approval, deposits/balances cannot be duplicated, and hosts only see valid approve/reject/complete actions.
- Improved simulated payment, receipt, and notification UI with clearer colors, payment-method cards, and next-step messaging.
- Simplified the explore search pill, organized venue cards with quick facts, and upgraded host/admin dashboards with actionable income and booking insights.

## 1.0.16+17 - 2026-05-31

- Kept customer, host, and admin tabs alive during bottom-navigation switches to avoid unnecessary reloads.
- Improved the profile page with a cleaner account summary and settings-style actions.
- Cleaned up admin user cards/details and changed admin booking management into view-only booking records.

## 1.0.15+16 - 2026-05-30

- Added embedded venue-name coordinate fallbacks so the APK shows accurate demo map markers even before a backend redeploy finishes.

## 1.0.14+15 - 2026-05-30

- Added OpenStreetMap-powered venue maps with markers on venue detail pages.
- Added venue latitude/longitude support in the backend and seeded Region 8 demo coordinates.
- Updated the Android release build to include the live map experience.

## 1.0.13+14 - 2026-05-30

- Added verified public venue photo URLs for key Region 8 demo venues while keeping fallback images for reliability.
- Updated the seed flow so venue-specific images can be mixed with generic fallback images.

## 1.0.12+13 - 2026-05-30

- Added researched Region 8 real venue seed data with realistic demo capacities and price estimates.
- Replaced broken seed image URLs and hardened venue image URL handling.
- Improved the host create/edit venue form with clearer sections, icons, validation, photo requirements, and location presets.
- Updated the customer location topbar to show only places that currently have venues.

## 1.0.11+12 - 2026-05-30

- Redesigned the login and account creation screens with a light-blue wave header and cleaner form presentation.
- Removed the extra login subtitle text.
- Added register input icons, password visibility toggles, confirm password input, and password-match validation.

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
