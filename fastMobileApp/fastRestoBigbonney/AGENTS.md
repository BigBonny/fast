# Flutter app verification

- The project selects Puro's `stable` environment in `.puro.json`. Use that Flutter SDK for builds and analysis.
- Run `flutter analyze` and `flutter test` from this directory. Static analysis does not replace live Android navigation and permission tests.
- For isolated emulator testing, build with `flutter build apk --debug --dart-define=FAST_API_URL=http://127.0.0.1:3300/api` and forward the local service using `adb -s <emulator> reverse tcp:3300 tcp:3300`. Without the define, the production API URL remains the default.
- The backend uses PostgreSQL and Prisma. `backend/prisma/seed.ts` deletes existing data before seeding; never run it against a shared or production database. Use a separate local database and non-destructive fixtures for audits.
- Authenticated UI tests must cover fresh sign-in and cold restart independently for customer, owner, staff, and guest roles. Keep orders, payments, menu mutations, and account operations confined to test fixtures.
