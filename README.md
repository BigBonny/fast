# FAST — click & collect

*Chaque minute compte.* Customers order ahead from partner restaurants, pay
in-app with Stripe, and pick up with a QR code or a typed `XXXX-FAST` code.

## What's in this repo

| Part | Where | Stack | Deploy |
|------|-------|-------|--------|
| Website (customers + partner dashboard) | repo root: `app/`, `components/`, `lib/`, `api/` | Next.js 14 (App Router), Tailwind | Vercel, project `fast` |
| Mobile app (customer + FAST Pro) | `fastMobileApp/fastRestoBigbonney` | Flutter, Provider | Codemagic (`codemagic.yaml`) |
| Backend API | `fastMobileApp/fastRestoBigbonney/backend` | Express, TypeScript, Prisma, PostgreSQL (Supabase) | Vercel, on push to `master` |

`api/fastBackend.ts` is the website's client for the backend API, not
server routes.

## Website

Uses **pnpm** (version pinned in `package.json`).

```bash
pnpm install
pnpm dev        # http://localhost:3000
pnpm build
pnpm lint
```

Environment (`.env.local`):

- `NEXT_PUBLIC_API_URL`: backend base URL including `/api`. Defaults to the
  production backend.
- `NEXT_PUBLIC_GOOGLE_CLIENT_ID`: Google Sign-In web client ID.

Security headers (CSP, framing, HSTS) and the image host allowlist live in
`next.config.js`. If you add a third-party script, API or image host,
update them there; the image hosts must also match
`components/SafeImage.tsx`.

## Mobile app

The Flutter SDK is managed by Puro (`.puro.json`, stable env):

```bash
cd fastMobileApp/fastRestoBigbonney
puro dart analyze lib/
puro flutter test
puro flutter run
```

See `fastMobileApp/fastRestoBigbonney/CLAUDE.md` for structure and
conventions.

## Backend

```bash
cd fastMobileApp/fastRestoBigbonney/backend
npm install
npm run dev
npx tsc --noEmit
npm test
```

Copy `.env.example` to `.env`. Schema changes are applied with
`npx prisma db push` **before** deploying code that uses them; the Vercel
build does not change the database.

> Never run `prisma/seed.ts` against the shared or production database:
> it deletes existing data first. Use a separate local database.

More project rules: [`CLAUDE.md`](CLAUDE.md).
