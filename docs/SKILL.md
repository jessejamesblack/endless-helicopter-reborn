---
name: endless-helicopter-docs
description: Use when editing project documentation, setup guides, architecture notes, runbooks, release notes, or agent-facing guidance under docs/.
---

# Docs

## Documentation Role

- Docs are the source of truth for repeated project decisions.
- Keep `AGENTS.md` short and use docs for durable detail.
- Update docs when behavior, setup, validation, exports, or operator steps change.
- Prefer linking to existing docs instead of duplicating long instructions.

## Runbooks

- Treat Android continuity, Supabase reset, signing, and release procedures as runbooks.
- Do not casually edit runbook order; preserve explicit step sequencing.
- Include concrete commands when an operator must run something.
- Include safety warnings where a step can affect live data, signing identity, or release publishing.

## Release Notes

- Update `docs/release_notes/latest.md` and `docs/release_notes/discord_summary.md` for release candidates.
- Keep release notes player-facing and concise.
- Do not bump versions only because docs changed unless a release candidate is being prepared.

## Validation

- For docs-only changes, run a quick link/path sanity search when references change.
- For docs that describe code behavior, run the relevant validator or explain why no validator was needed.
