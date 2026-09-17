# Hasani WhatsApp Campaign

Standalone campaign console for opted-in Hasani Books customers. The application uses Next.js/TypeScript, Supabase Auth/PostgreSQL and a server-side WhatsApp provider adapter.

## 1. Supabase

Create a NEW Supabase project for this application. In Supabase SQL Editor run `supabase/migrations/001_initial.sql`. In Authentication create the administrator user/email that will sign in to this console.

## 2. Environment

Copy `.env.example` to `.env.local` and fill:

- `NEXT_PUBLIC_SUPABASE_URL` — Supabase Project URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` — Supabase anon/publishable key
- `SUPABASE_SERVICE_ROLE_KEY` — server only; never expose in browser
- `QUEUE_WORKER_SECRET` — long random secret used only by the scheduler/worker
- `WHATSAPP_PROVIDER=mock` — safe development mode
- webhook/provider fields — fill only when an official provider is connected

Never commit `.env.local`.

## 3. Run locally

```bash
npm install
npm run typecheck
npm run dev
```

Open `http://localhost:3000/login` and sign in with the Supabase Auth administrator account.

## 4. Customer import

Open `/customers`. Upload XLSX/XLS/CSV. Supported headers are `CUSTOMER CODE`, `CUSTOMER NAME`, `PHONE`, `EMAIL`, `CONSENT`. Malaysian mobile numbers are normalized to `+60`. Only rows with explicit `YES`, `Y`, `TRUE` or `1` consent are imported. Invalid, duplicate-in-file and non-consented rows are rejected.

## 5. Campaign processing

Campaign recipients are inserted only from active opted-in customers and are blocked by the opt-out register. Queue processing is server-only:

```bash
curl -X POST http://localhost:3000/api/queue/process -H "Authorization: Bearer YOUR_QUEUE_WORKER_SECRET"
```

Schedule this endpoint from a trusted server/cron. Do not call it from browser JavaScript.

## 6. Provider

Keep `WHATSAPP_PROVIDER=mock` until the official WhatsApp Business provider account is ready. The mock adapter creates test message IDs but sends nothing. Production provider credentials belong only in deployment environment secrets. The generic HTTP adapter is intentionally provider-neutral; adapt its payload and webhook authentication to the selected provider's official documentation before enabling live sending.

## 7. Webhook

Point the provider webhook to `/api/webhooks/whatsapp`. Configure `WHATSAPP_WEBHOOK_VERIFY_TOKEN` and `WHATSAPP_WEBHOOK_SECRET` according to the provider integration. The endpoint maps sent/delivered/read/failed events into message and recipient records.

## 8. Production

Build with `npm run build`. A `Dockerfile` is included. Configure all environment variables in the hosting platform, run the SQL migration once, keep `SUPABASE_SERVICE_ROLE_KEY`, provider token, queue secret and webhook secret server-only, and use HTTPS. GitHub Actions validates TypeScript and the production build.

## Important

This repository deliberately does not contain provider credentials. Marketing campaigns must have valid recipient consent and opt-outs must be honored. Do not use personal WhatsApp Web automation or mechanisms intended to bypass provider/platform limits.
