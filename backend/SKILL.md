---
name: endless-helicopter-backend
description: Use when editing backend/, Supabase SQL, Edge Functions, leaderboard/profile schema assumptions, data reset scripts, or backend-adjacent setup docs.
---

# Backend

## Safety

- Treat Supabase data as live unless a local development project is clearly configured.
- Default MCP access is read-only by design.
- Do not run ad hoc writes against Supabase.
- Use checked-in SQL scripts and documented runbooks for migrations, wipes, or restore validation.

## Data Model Expectations

- Shared leaderboard and synced profile data live in Supabase.
- Profile sync should preserve local-first gameplay behavior.
- Prefer JSON summary compatibility for new progression fields when possible.
- Avoid schema migrations for unlock-pool or summary-only additions unless validation proves they are required.

## Edge Functions

- Keep push/notification changes compatible with Firebase Cloud Messaging setup in `docs/PUSH_NOTIFICATIONS_SETUP.md`.
- Avoid committing secrets, service-role keys, Firebase configs, or generated credentials.
- Update setup docs when operator steps change.

## Validation

- For reinstall/restore behavior, use `tools/validate_supabase_reinstall_restore.ps1`.
- For cutover or wipe work, read `docs/ANDROID_CONTINUITY_CUTOVER.md` before editing or running anything.
- For normal Godot-facing backend assumptions, run `tools/validate_godot.ps1`.
