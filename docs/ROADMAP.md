# Roadmap

This roadmap keeps the project pointed at small, testable milestones. It is not a release promise; it is the current working direction for the next few passes.

## 1.6.x cleanup

- Keep release/version metadata synchronized across export presets, build info, release notes, Discord summaries, and GitHub releases.
- Polish the public repo surface with clearer README install links, gameplay media, issue templates, and contribution entry points.
- Continue tightening Android continuity, daily mission sync, push notification copy, and release validation.
- Preserve the current no-store, no-paid-upgrades direction while the core loop is still being tuned.

## 1.7 gameplay content

- Ship a broader short-objective deck that teaches movement, restraint, projectile intercepts, clean flying, and elite-target combat without turning runs into chores.
- Bias future objective/event content around vehicle identity now that Scout has a visible first-choice upgrade passive.
- Add biome events such as storm pockets, low-visibility sections, gravity pulses, or temporary hazard waves.
- Expand enemy roles with a small number of readable threats, such as mine layers, shield projectors, carrier drones, or warning-based turrets.
- Add vehicle-specific challenges that help players understand each passive identity.
- Add more vehicles and skin sets after the current vehicle identities are balanced, with each new vehicle bringing a clear silhouette, passive hook, and Hangar-readable stats.

## 1.8 refactor

- Split the largest gameplay and profile scripts into smaller feature modules once the current systems settle.
- Move stable HUD and depth-system panels out of ad hoc runtime construction where scenes/themes would be easier to maintain.
- Separate mission generation, live progress, persistence, cloud merge, and reward application behind clearer internal boundaries.
- Keep refactors behavior-preserving and covered by validators before adding more content on top.

## 1.9 validation

- Expand string/token validators into behavior checks for seeded runs, mission progress, profile save/load, and layout smoke tests.
- Add deterministic run simulation coverage for upgrade timing, objectives, scoring, pause/resume timing, and mission reconciliation.
- Add profile/cloud merge tests for stale rows, newer local progress, queued payloads, and same-day mission completion.
- Keep validators fast enough to run in normal PR CI.

## 2.0 public-ready

- Harden public competition paths with server-side sanity checks, rate limits, narrower write policies, and stronger identity assumptions.
- Investigate Android APK size, exported resource scope, audio compression, texture sizes, memory use, and low-end device performance.
- Add first-run onboarding, a clearer crash summary, post-run tips, a vehicle/passive glossary, and accessibility polish.
- Implement a non-AI art pass for core player-facing assets, prioritizing vehicles, skins, pickups, enemies, backgrounds, and store/release media that need a cohesive final style.
- Decide whether the project is still friends-and-family focused or ready for broader public leaderboard expectations.

## Backlog Seeds

- Balance report or CSV export for run length, death reasons, vehicle differences, upgrade picks, powerup use, and objective outcomes.
- More README media and release-page polish as the art and UI stabilize.
- Vehicle and skin concept backlog with unlock requirements, passive identity notes, silhouette requirements, and non-AI final-art status.
- Play Store readiness work only after signing, privacy, telemetry, and public leaderboard expectations are settled.
