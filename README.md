# Hasani WhatsApp Campaign

Production-oriented bulk WhatsApp campaign management for opted-in customers.

## Planned capabilities

- Supabase authentication and PostgreSQL data layer
- Customer Excel/CSV import and Malaysian phone normalization
- Duplicate, invalid-number, consent and opt-out controls
- WhatsApp template management
- Campaign creation, preview, scheduling and lifecycle controls
- Server-side message queue with retry/idempotency safeguards
- Provider adapter (mock mode until official provider credentials are configured)
- Webhook processing for sent/delivered/read/failed events
- Campaign reporting and audit trail
- CI, tests and production deployment configuration

## Safety and production rule

Provider credentials and Supabase service-role credentials must only be configured as server-side environment secrets. Never commit them to this repository or expose them to browser code.

Bulk marketing campaigns must only target recipients with valid WhatsApp marketing consent and must honor opt-outs.

## Status

Initial repository bootstrap. Application implementation follows on the `codex/production-bootstrap` branch.
