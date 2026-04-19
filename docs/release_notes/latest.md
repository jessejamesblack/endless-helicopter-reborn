# Endless Helicopter Reborn 1.6.0

Sprint 6 is the release-ops and polish update. It makes the Android build much easier to ship and support, adds safer update and reporting flows for family installs, and gives longer runs more movement, more identity, and more pressure.

## Highlights

- Android releases now publish cleaner GitHub release notes, checksum details, release metadata, and Discord build posts.
- The game now supports optional update prompts, required-update lockouts, and release-channel-aware app-update push notifications.
- Family support tools are much stronger: in-app feedback, safer bug-report copying, centralized client error reporting, and developer email alerts.
- Daily missions now reset at 8:00 AM ET year-round, matching America/New_York through both EST and EDT.
- Backgrounds feel more alive, visible biomes have music mapping support, and midgame and late-game pacing are noticeably tougher.

## Player-Facing Changes

- The start screen can now surface update prompts and block play when an installed build is below the minimum supported version.
- Settings now shows version, build, channel, update status, screenshot-sharing preference, and family feedback tools.
- Daily missions clearly show `Resets daily at 8:00 AM ET`.
- Background motion is more visible, biome transitions feel livelier, and long runs escalate harder after the early fair opening.
- Major family milestones can now feed into safer reporting and screenshot-sharing flows without embedding Discord secrets in the app.

## Family Ops And Support

- Score-beaten, daily-mission, and release events can post to Discord without a full bot.
- Release builds now publish SHA-256 integrity information alongside the APK and release link.
- Version adoption data is tracked by build and release channel to help spot outdated installs.
- Weekly recap support, achievement screenshot posting, and safer internal feedback/reporting are now wired into the release stack.

## Safety Notes

- Discord posts disable mass mentions.
- Release and error-reporting paths are best-effort and do not block gameplay if a webhook, push, or backend call fails.
- Operational logs avoid raw secrets, webhook URLs, and push tokens.
