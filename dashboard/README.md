## AgriLink Dashboard (Next.js)

This dashboard is a web management interface for AgriLink mobile users.

### What it supports now

- Sign in with the same email/password as mobile (Supabase Auth)
- Edit profile details
- View and delete your posts
- View and delete your marketplace listings
- View and delete your events
- View and delete your workshop files
- View and delete your repository files

Account creation is intentionally mobile-first. The sign-in page directs new users to create an account in the mobile app.

## Local setup

1. Copy env vars:

```bash
cp .env.example .env.local
```

2. Fill in:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- Optional: `NEXT_PUBLIC_ADMIN_EMAILS` (comma-separated admin emails)

3. Install and run:

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Vercel deployment

- Framework preset: Next.js
- Root directory: `dashboard`
- Set the same two env vars in Vercel project settings

## Notes

- Data access depends on your Supabase RLS policies.
- This dashboard assumes your existing mobile tables and storage buckets are already in place.
- Admin tab visibility is currently based on:
  - email included in `NEXT_PUBLIC_ADMIN_EMAILS`, or
  - `user_profiles.role = 'admin'` (if that column exists in your schema).
