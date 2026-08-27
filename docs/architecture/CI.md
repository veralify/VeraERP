# CI and Release Infrastructure

## Workflows

- `web-ci.yml` runs on web-impacting pull requests and pushes to `main`. It installs pnpm with a frozen lockfile, runs Biome lint, runs `tsc --noEmit`, and builds Next.js with fake public Supabase placeholders so CI does not require secrets.
- `db-ci.yml` runs on `supabase/**` changes. It starts a local Supabase database, resets from all migrations, runs database tests only when `supabase/tests` contains files, and lints the local database schema. Warning-level lint output is reported without blocking unless error-level lint also fails.
- `functions-ci.yml` runs on `supabase/functions/**` changes. It sets up Deno, checks formatting, lints Edge Functions, and runs tests only when function test files exist.
- `ios-ci.yml` runs on `veralify-App/**` changes on `macos-15`. It builds the `veralify` scheme from `veralify-App/iOS/veralify/veralify.xcodeproj` without code signing. Unit/UI tests are omitted until the test target finishes reliably in CI; local `xcodebuild test` did not complete quickly.
- `deploy-supabase.yml` is manual (`workflow_dispatch`) and pushes migrations plus deploys Edge Functions after verifying required secrets are present.

## GitHub secrets for future deploy workflows

- `VERCEL_TOKEN`
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_DB_PASSWORD`
- `SUPABASE_PROJECT_REF`

## Deploy strategy

Web deployments remain on Vercel auto-deploy for the connected repository/project. Supabase deploys are intentionally manual for the pivot build: run the `Deploy Supabase` workflow, which links the configured project, executes `supabase db push`, and deploys all Edge Functions with `supabase functions deploy`.
