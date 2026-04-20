# MCP Setup

This repo ships a project-scoped Codex MCP configuration in [`.codex/config.toml`](../.codex/config.toml) and a VS Code MCP configuration in [`.vscode/mcp.json`](../.vscode/mcp.json).

## Included By Default

- `supabase`
  Scoped to project `lxvniafwjlwatbiblwyi`
  Runs in read-only mode on purpose
  Authenticates from `SUPABASE_ACCESS_TOKEN` when that environment variable is set
- `openaiDeveloperDocs`
  Public OpenAI documentation MCP server
- `context7`
  Local stdio MCP server for up-to-date third-party docs

## Why Supabase Is Read-Only

This project already points at a live Supabase project in runtime code. Supabase recommends using MCP against development data, and read-only mode is the safest default when a project may contain real data or live configuration.

If you need write-capable Supabase MCP access later, duplicate the `supabase` entry locally and remove `read_only=true` from the URL in your own uncommitted config.

## Local Write Override

For normal Codex and VS Code work, keep the repo config in read-only mode.

When you need to validate or apply a live migration deliberately:

1. Keep `SUPABASE_ACCESS_TOKEN` available in your shell or IDE process.
2. Use a local-only override that points to `https://mcp.supabase.com/mcp?project_ref=lxvniafwjlwatbiblwyi` without `read_only=true`.
3. Prefer deterministic scripts that wrap any synthetic writes in `begin; ... rollback;`.

Any live Supabase wipe or migration should use a deliberate write-capable override plus a reviewed runbook. Do not use ad-hoc MCP writes for Android continuity cutovers or gameplay-data resets; use [ANDROID_CONTINUITY_CUTOVER.md](ANDROID_CONTINUITY_CUTOVER.md), the checked-in wipe script [backend/supabase_fresh_start_cutover_wipe.sql](../backend/supabase_fresh_start_cutover_wipe.sql), and an explicit operator checklist.

This repo now includes [tools/validate_supabase_reinstall_restore.ps1](../tools/validate_supabase_reinstall_restore.ps1), which uses that write-capable endpoint only for a transaction-wrapped reinstall/restore validation and leaves no persistent test data behind.

## First-Time Setup

### Codex CLI / Codex IDE extension

1. Trust the project if prompted.
2. Run `codex mcp list`.
3. Ensure `SUPABASE_ACCESS_TOKEN` is available in your shell or user environment.
4. Restart the Codex client if the new tools do not appear immediately.

If you do not have a personal access token available yet, create one in your Supabase account settings and export it as `SUPABASE_ACCESS_TOKEN`. This project intentionally uses the hosted read-only MCP endpoint, so a token is enough and no project-local secret file is needed.

### VS Code MCP

1. Open the workspace in VS Code.
2. Ensure `SUPABASE_ACCESS_TOKEN` is available to the VS Code process.
3. Open the MCP configuration UI if prompted by your agent extension.
4. Reload the window if the tools do not appear immediately.

## Context7 Notes

This repo enables Context7 in both the project-scoped Codex config and the VS Code MCP config.

- On this machine, Context7 is wired to `C:\Program Files\nodejs\npx.cmd` so it still works even if a newly installed Node.js has not reached the current shell `PATH` yet.
- If your Node install lives somewhere else, update the `command` field in [`.codex/config.toml`](../.codex/config.toml).
- If you also use VS Code MCP, update the matching `command` field in [`.vscode/mcp.json`](../.vscode/mcp.json).
- After changing Node installs, restarting the IDE or terminal is often enough to pick up the new `PATH`.
- Context7 does not need an OAuth login for the basic docs flow, so once the server appears in your MCP client it is ready to use.

Context7 is useful here for up-to-date Godot, Firebase, Android, and Supabase docs.

Source:

- OpenAI Codex MCP docs: `codex mcp add context7 -- npx -y @upstash/context7-mcp`
- Upstash Context7 MCP package: `@upstash/context7-mcp`

## Optional Add-Ons

### GitHub

Use for PRs, issues, workflow runs, and release/admin tasks beyond plain `git`.

Requirements:

- Docker
- `GITHUB_PERSONAL_ACCESS_TOKEN`

Recommended Codex config:

```toml
[mcp_servers.github]
command = "docker"
args = [
  "run",
  "-i",
  "--rm",
  "-e",
  "GITHUB_PERSONAL_ACCESS_TOKEN",
  "-e",
  "GITHUB_TOOLSETS",
  "ghcr.io/github/github-mcp-server",
]
env_vars = ["GITHUB_PERSONAL_ACCESS_TOKEN"]

[mcp_servers.github.env]
GITHUB_TOOLSETS = "repos,issues,pull_requests,actions"
```

## References

- OpenAI Codex MCP docs: https://developers.openai.com/codex/mcp
- OpenAI Docs MCP: https://developers.openai.com/learn/docs-mcp
- Supabase MCP docs: https://supabase.com/docs/guides/getting-started/mcp
- GitHub MCP server: https://github.com/github/github-mcp-server
