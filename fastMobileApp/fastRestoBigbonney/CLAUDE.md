# FAST mobile app — Flutter (customer + FAST Pro)

Single Flutter codebase containing the customer app and the restaurant
("FAST Pro") side, switched by role after login. Provider for state,
custom design system in `lib/widgets/fast_ui.dart` + `lib/theme.dart`.

## Commands (Puro stable SDK — see `.puro.json`)

```bash
puro dart analyze lib/          # static analysis
puro flutter test               # unit + widget tests
puro flutter run                # run on device/emulator
puro flutter build apk --debug --dart-define=FAST_API_URL=http://127.0.0.1:3300/api
```

For emulator API testing also run
`adb -s <emulator> reverse tcp:3300 tcp:3300`. Without the dart-define
the production API URL is used.

## Structure

- `lib/main.dart` — app entry, role routing, customer shell
  (`MainShell` + `FastNavBar`), `DriverShell` (hidden).
- `lib/screens/` — customer screens (`home_screen`, `restaurant_screen`,
  `cart_screen`, `commandes_screen`, `group_screen`, `qr_screen`,
  `account_screen`, `saved_addresses_screen`, `saved_cards_screen`,
  `assistant_screen`, `story_viewer_screen`).
- `lib/screens/resto/` — FAST Pro: `resto_shell.dart` (nav),
  `resto_orders_screen`, `resto_menu_screen`, `resto_stats_screen`,
  `resto_settings_screen`, `resto_staff_screen`,
  `resto_reservations_screen`, `resto_profile_screen`, `kitchen_screen`
  (KDS), `menu_item_edit_screen`, `menu_ai_scanner_screen`,
  `onboarding_screen`, `guest_menu_shell.dart`.
- `lib/provider.dart` — `FASTProvider` (customer state).
- `lib/resto_provider.dart` — `RestoProvider` (restaurant state).
- `lib/models.dart` — shared models incl. `pickupCodeFromToken`,
  `Order.fromApiJson` status parsing.
- `lib/services/` — `proximity_service.dart` (background GPS +
  `PickupTracker` movement gate), `order_service.dart`,
  `location_service.dart`, payment/auth/etc.
- `lib/l10n/app_strings.dart` — all locales in one file (~9 languages,
  repeated sections). `lib/l10n/tr.dart` — `tr(context, 'key')`.
- `lib/theme.dart` — `context.fast` theme extension (FASTShades).

## Conventions

- UI strings always via `tr(context, 'key')` / `provider.tr('key')` —
  never hardcode user-facing text. Add the key to EVERY locale section.
- Async gaps: check `mounted` before `setState`/navigation; avoid
  `BuildContext` across awaits without `if (!mounted) return;`.
- Maps: MapLibre (`maplibre` package) + OpenFreeMap style; enable
  gestures eagerly inside scroll views or the map renders but can't be
  touched. External directions via `url_launcher` (Apple Maps on iOS,
  Google Maps elsewhere).
- Order card colors (Pro): yellow = client en route ONLY; violet =
  preparing; don't reuse amber for status.
- Compact Pro order cards expand on tap — keep header chips, ETA,
  timer and action buttons visible when collapsed.

## Testing

- `test/` — unit tests (`pickup_tracking_test.dart` covers the
  `PickupTracker` movement gate + shared pickup-code vector;
  `order_status_test.dart`, `menu_item_form_test.dart`) and
  `widget_test.dart` smoke tests.
- Authenticated UI flows (fresh sign-in + cold restart for customer,
  owner, staff, guest) must be verified manually — static tests don't
  cover them.
- Real-device checks still needed for: background GPS tracking on iOS,
  FCM cold-start tap, PaymentSheet 3DS.
