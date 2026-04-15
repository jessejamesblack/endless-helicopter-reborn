# AI Collaboration

This project borrows practical ideas from OpenAI's harness-engineering approach and adapts them to a small Godot game.

## Principles Applied Here

### 1. Humans steer, agents execute

- Humans decide goals, priorities, and acceptance criteria.
- Agents implement, validate, and document changes.

### 2. Repository knowledge is the system of record

- Important context should live in the repo, not only in chat.
- `AGENTS.md` is the map.
- `docs/` holds the deeper sources of truth.

### 3. Agent legibility matters

- The repo is organized by feature so agents can navigate it quickly.
- Shared systems and setup files are separated from scene logic.
- Validation commands live in `tools/`.

### 4. Encode repeatable behavior

- Repeated checks become scripts.
- Repeated build steps become CI.
- Repeated structural guidance becomes docs.

### 5. Keep feedback loops tight

- Validate changed scripts with Godot.
- Build Android artifacts in CI on push.
- Update docs when the system shape changes.

## Expectations For Future AI Work

- Read `AGENTS.md` first.
- Prefer the smallest relevant doc instead of stuffing everything into one file.
- Keep structural changes deliberate and documented.
- If a new recurring rule appears, promote it into docs or tooling.
