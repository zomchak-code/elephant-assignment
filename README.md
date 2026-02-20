# Courses App (Flutter + Bun)

## Env requirements

- Bun installed
- Flutter installed

## Setup env files

Get env variables from a teammate

## Run backend

From repo root:

```sh
cd backend

# Install deps
bun i

# Load env vars from backend/.env for this shell
set -a
source .env
set +a

# Run DB migration (creates only: users, courses, learners, modules)
bun run migrate

# Start server
bun run dev
```

Backend runs on `http://localhost:$PORT` (default `3000`).

## Run mobile app

From repo root:

```sh
cd mobile
flutter pub get

# Load mobile env vars into the shell (optional helper)
set -a
source .env
set +a

# Flutter does not read .env automatically; pass values as --dart-define
flutter run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=BACKEND_BASE_URL="$BACKEND_BASE_URL"
```
