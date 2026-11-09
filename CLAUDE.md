# FAST — click & collect food ordering platform

Customers order ahead from partner restaurants, pay in-app (Stripe), and
pick up with a QR or typed `XXXX-FAST` code. Tagline: "Chaque minute
compte". Brand teal `#00C8B3`, magenta `#FF0066`.

## Layout

- **Website** (Next.js): repo root — `app/`, `components/`, `api/`,
  `lib/`. Deployed on Vercel/Netlify.
- **Flutter app**: `fastMobileApp/fastRestoBigbonney` — customer app and
  FAST Pro (restaurant side) in one codebase, Provider state management,
  9 locales with RTL.
- **Backend API**: `fastMobileApp/fastRestoBigbonney/backend` — Express +
  TypeScript + Prisma + PostgreSQL (Supabase), deployed on Vercel.

@fastMobileApp/fastRestoBigbonney/AGENTS.md

## Commands

- Flutter SDK is Puro-managed (stable env): use `puro flutter ...` and
  `puro dart analyze` — plain `flutter` may not be on PATH.
- App analyze: `cd fastMobileApp/fastRestoBigbonney && puro dart analyze lib/`
- App tests: `puro flutter test`
- Backend: `cd fastMobileApp/fastRestoBigbonney/backend && npx tsc --noEmit`
  and its test suite (`npm test`).
- Backend deploys automatically on push to `master` via Vercel.

## Hard rules (learned the hard way)

- NEVER run `backend/prisma/seed.ts` against a shared/prod database — it
  deletes existing data first. Use a separate local DB.
- Never expose private Stripe/Connect fields in public restaurant API
  responses.
- Pickup codes: `XXXX-FAST` is derived deterministically from
  `pickupToken` — keep the Dart port (`models.dart`
  `pickupCodeFromToken`) and TS source (`backend/src/utils/pickupToken.ts`)
  in sync; a shared test vector pins them together.
- Pickup tracking must go through `PickupTracker`'s movement gate —
  bypassing it makes Pro order cards turn yellow on GPS jitter.
- Auto-accept closing-time logic is Paris-timezone aware
  (`backend/src/utils/autoAccept.ts`) — don't reintroduce server-local
  time.
- Every new UI string needs all ~9 locales in `lib/l10n/app_strings.dart`.
  The brand name "FAST" is never translated.
- Driver/livreur UI exists in code but must stay hidden unless the user
  explicitly asks for it.
- Logging out must never delete account data.

## Architecture notes

- Order statuses: `PLACED → PREPARING → READY_FOR_PICKUP → COMPLETED`
  (+ `CANCELLED`). Paid orders auto-accept to PREPARING unless within
  30 min of closing.
- Payments: Stripe PaymentSheet in-app; Stripe Connect for restaurant
  payouts; platform-collect bypass via
  `FAST_PLATFORM_COLLECT_RESTAURANT_IDS` env (comma-separated restaurant
  IDs).
- Realtime-ish updates: polling + Firebase Cloud Messaging push; pickup
  proximity/GPS tracking runs in `ProximityService` with background
  location on iOS (`UIBackgroundModes: location` in Info.plist).
- Address autocomplete uses the French BAN API (not Nominatim).
- AI features (assistants, menu scanner) use Google Gemini.
