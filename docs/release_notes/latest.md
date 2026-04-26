# Endless Helicopter Reborn 1.7.0

Version 1.7.0 is a run-variety and skill-expression update. It builds on the 1.6 depth sprint by making objectives appear earlier, adding more ways to succeed or fail inside a run, and giving Scout a visible upgrade-choice identity.

## Highlights

- Objectives can now begin around 42 seconds, are spaced at least 32 seconds apart, and can appear up to three times per run.
- Expanded the objective deck to eight events: Rescue Pickup, Reactor Chain, Black Box Recovery, Signal Gates, No-Fire Signal, Barrage Intercept, Bounty Drone, and Clean Flight.
- No-Fire Signal rewards restraint by failing if the player successfully fires a missile before the timer ends.
- Clean Flight rewards control by failing if the player uses boundary recovery before the timer ends.
- Barrage Intercept spawns a small drone pressure setup and rewards projectile interception with an ammo refill.
- Bounty Drone spawns a marked elite drone after the run has reached the later objective window and rewards the kill with an upgrade choice.
- Black Box Recovery now uses two alternating-lane boxes, and Signal Gates reward Score Rush for precision flight.
- Objective selection avoids repeating the same event in one run until the available deck is exhausted.

## Vehicle And UI Changes

- Scout now uses the Reliable Frame passive.
- Reliable Frame makes Scout's first upgrade choice offer four cards instead of three, giving the starter vehicle a clearer identity.
- Later Scout choices and all other vehicle choices continue to use the normal three-card upgrade flow.
- The upgrade choice overlay now supports the four-card Scout layout on supported phone and tablet widths.
- The Hangar stat readout now describes Scout's first-choice card bonus.

## Technical Notes

- Objective data now supports timer completion, fail actions, elapsed gating, start events, lane-mode pickup spawning, and reward-specific handling.
- Main gameplay now records objective actions for successful missile fire, projectile intercepts, boundary recovery, reactor kills, and bounty kills.
- The spawner can launch objective-specific events for Barrage Intercept and Bounty Drone and can place objective pickups in requested lanes.
- Marked bounty enemies use existing elite behavior plus objective-destroy action plumbing.
- Default objective availability now includes the full v1.7 objective deck, while existing profile objective fields remain backward-compatible.
- No Supabase schema migration or backend update is required.

## Validation

- Added behavior validation for objective cadence, the eight-objective catalog, no-repeat objective selection, elapsed gating, timer completion, fail actions, projectile-intercept completion, bounty completion, lane pickup support, and Scout's four-card first choice.
- Updated depth-retention, gameplay-content, hangar-polish, and feedback validators for the new release behavior.
- Full Godot validation passes for this release candidate.
