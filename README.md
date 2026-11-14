# School Library System — Backend

Supabase backend for the [frontend application](https://github.com/Kenshitawa/library-frontend).
This project contains PostgreSQL migrations, Row Level Security policies, seed data, Edge
Functions, and local Supabase configuration.

## Requirements

- Docker Desktop
- Supabase CLI
- Deno (for local Edge Function development)

## Local development

From the backend repository root:

```powershell
npx supabase start
npx supabase status
```

The local Supabase CLI applies database migrations and the development seed. Use `npx supabase
functions serve` while developing Edge Functions. Do not use the local seed data or auth seed
scripts in production.

The anonymous-access smoke tests require a running local project. Install the backend test
dependencies with `npm ci`, set `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `npx supabase status`,
then run `npm run test:rls`. The test fails rather than silently skipping when the local API cannot
be reached.

## Database and security

- Review `supabase/migrations/` in order. Apply new changes locally with `npx supabase migration
  up`; review and apply them to hosted projects through the normal release process.
- Row Level Security is enabled for exposed application tables. Keep privileged operations behind
  the role-checked SQL functions or the shared Edge Function librarian authorization.
- The service-role key and provider keys are server-side secrets only. Never commit real values or
  expose them in frontend environment variables.
- Public sign-up is disabled in the local Auth configuration. Librarian invitations are restricted
  to active librarian accounts.
- Use a separate Supabase project and test accounts for automated tests. Never run destructive
  local reset commands against a production project.

## Edge Functions and optional services

Deploy functions with `npx supabase functions deploy <function-name>` after linking the intended
project and reviewing its target. Catalog suggestions require the server-side `OPENAI_API_KEY`
secret; ISBN catalog lookup works without it.

Scheduled return reminders, monthly inventory snapshots, and expired-reservation warning letters
require `pg_cron`. Verify that the extension is enabled and each job is scheduled after deployment.
The inventory job saves a snapshot and creates an in-app notification; a librarian downloads the
CSV after opening it in the frontend.

Outbound email is deliberately reported as unavailable by `send-notification`: there is no
configured production mail provider. Do not mark email reminders as a supported delivery channel
until an authenticated provider is implemented and tested.

## Production checklist

- Set the hosted Supabase Auth site URL and exact redirect allow-list for the deployed frontend.
- Keep public signup disabled; configure a secure staff invitation and password reset process.
- Apply reviewed migrations and verify RLS/function grants in the hosted project.
- Configure function secrets with `npx supabase secrets set`; do not commit secrets or place them
  in the repository's example environment file.
- Enable backups and test restores; configure monitoring, abuse limits, and production network
  restrictions in the Supabase project.
- Verify `pg_cron` jobs, notifications, inventory snapshots, and scheduled warning behavior.
- Configure and validate email separately before enabling any email delivery claims.

The default library locale is Kenya: KES, `en-KE`, and `Africa/Nairobi`.
