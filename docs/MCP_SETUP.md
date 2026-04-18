# MCP Setup

This repo ships a project-scoped Codex MCP configuration in [`.codex/config.toml`](../.codex/config.toml) and a VS Code MCP configuration in [`.vscode/mcp.json`](../.vscode/mcp.json).

## Included By Default

- `supabase`
  Scoped to project `lxvniafwjlwatbiblwyi`
  Runs in read-only mode on purpose
- `openaiDeveloperDocs`
  Public OpenAI documentation MCP server
- `context7`
  Local stdio MCP server for up-to-date third-party docs

## Why Supabase Is Read-Only

This project already points at a live Supabase project in runtime code. Supabase recommends using MCP against development data, and read-only mode is the safest default when a project may contain real data or live configuration.

If you need write-capable Supabase MCP access later, duplicate the `supabase` entry locally and remove `read_only=true` from the URL in your own uncommitted config.

## First-Time Setup

### Codex CLI / Codex IDE extension

1. Trust the project if prompted.
2. Run `codex mcp list`.
3. Run `codex mcp login supabase`.
4. Restart the Codex client if the new tools do not appear immediately.

### VS Code MCP

1. Open the workspace in VS Code.
2. Open the MCP configuration UI if prompted by your agent extension.
3. Authenticate the `supabase` server when VS Code offers the OAuth flow.
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
