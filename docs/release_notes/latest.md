# Endless Helicopter Reborn 1.7.6

Version 1.7.6 is a profile-name, cloud-data hygiene, vehicle naming consistency, scoring polish, roadmap clarity, README media, and AI-collaboration documentation release. It keeps local development playable, but configured online builds now require a valid public pilot name before cloud profile creation, progression publishing, or protected online-facing menu flows.

## Highlights

- Added a Start Screen pilot-name gate for configured online builds.
- Play, Scores, Missions, and Hangar now wait for startup profile restore and then require a valid 1-12 character public name when no restored/cached name exists.
- Settings, Debug, Credits, and required update prompts remain accessible while the name gate is active.
- Blank or blocked cached names are now cleared instead of silently becoming `"Player"`.
- Profile sync jobs are no longer queued or flushed without a valid cached name.
- Hind Strike is now the canonical primary vehicle name in Hangar, missions, results, docs, and validation.
- Saved daily vehicle missions repair stale rendered vehicle names so mission copy stays aligned with the current Hangar name.
- Ammo pickups collected while already at full ammo now convert into score and show the normal floating score notifier.
- The roadmap now calls out future non-AI final art work plus more vehicles and skin sets.
- README gameplay media now includes current captures for upgrade choices, results, Hangar stats, pause, settings, missions, and the run view.
- README and AI collaboration docs now mention the repo's root/folder `SKILL.md` guidance, README media capture workflow, release-hygiene checks, and progression-path validators.

## Backend And Data Hygiene

- `sync-player-profile` now rejects missing names with HTTP `422` before calling the database RPC.
- `sync_player_profile` now requires a 1-12 character name, writes the submitted valid name, and returns `name`.
- `get_player_profile` now returns `name` directly from the RPC, so the Edge Function no longer needs a fallback profile-table query.
- Supabase setup SQL backfills existing blank profile/run-history names, generates safe temporary `Pilotxxxxxx` names when needed, and aborts if duplicate normalized profile names remain.
- Synced profile names now have a required-name constraint, non-null column enforcement, and family-scoped normalized uniqueness.

## Validation

- Added focused validation for strict cached-name handling, Start Screen gate behavior, protected menu blocking, profile-sync queue guards, Edge Function validation, and SQL data hygiene.
- Updated naming validation so Hangar, results, and mission copy use backend canonical vehicle names.
- Added coverage for saved vehicle missions with stale names being repaired to Hind Strike.
- Added coverage that full-ammo pickups use the shared score-award path and show feedback at the pickup position.
- Updated public-polish validation so every README media path, including the new captures, must exist and be referenced.
- Updated live reinstall/restore validation so synthetic profile rows use valid public names.
