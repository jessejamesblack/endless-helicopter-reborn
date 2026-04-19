# Endless Helicopter Reborn 1.6.0

Sprint 6 turns the game into something much easier to ship, update, monitor, and support while also tightening the feel of long runs.

## Highlights

- Added release ops automation for versioned Android releases, rolling latest links, checksums, release metadata publishing, and Discord build posts.
- Added in-app update checks, required-update enforcement, and app-update push notifications routed by release channel.
- Added centralized client error reporting, developer email alerts, and safer bug-report feedback from inside the game.
- Moved daily mission reset to 8:00 AM America/New_York so the schedule matches family play habits through both EST and EDT.
- Increased background parallax motion, added biome-specific music hooks, and tuned midgame and late-game encounter pressure upward.
- Added version adoption tracking, family feedback flow, weekly recap support, and achievement screenshot sharing through Supabase.

## Player-Facing Changes

- Settings now exposes update status, build details, screenshot sharing, and family feedback tools.
- Start screen can show optional updates or block play when the installed build is below the minimum supported version.
- Daily mission UI now clearly communicates the 8:00 AM ET reset.
- Biomes feel more alive thanks to stronger layer separation, moving accents, and cleaner music transitions.
- Runs stay fair early, then ramp harder after 30 seconds, with a much stronger 2+ minute intensity curve.

## Ops Notes

- Discord release posts always include a GitHub release link and SHA-256 checksum.
- Game-event Discord posts do not ping `@everyone` or `@here`.
- Edge functions and logs now avoid storing raw secrets, webhook URLs, and push tokens in operational text fields.
