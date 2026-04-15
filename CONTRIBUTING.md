# Contributing

This repository now uses a branch-and-pull-request workflow for changes to `main`.

## Branch Flow

1. Start from an up-to-date `main`.
2. Create a branch for your work.
3. Push the branch to GitHub.
4. Open a pull request into `main`.
5. Wait for CI to pass.
6. Merge the pull request instead of pushing directly to `main`.

Suggested branch names:

- `feature/...`
- `fix/...`
- `chore/...`
- `docs/...`

## Pull Requests

- Keep pull requests scoped to one change or one feature.
- Use the PR template in `.github/pull_request_template.md`.
- Mention any gameplay risks or follow-up work.
- If CI fails, fix the branch before merging.

## Main Branch Policy

- `main` should stay releasable.
- Android releases are published from pushes to `main`.
- Direct pushes to `main` should be disabled in GitHub branch protection or rulesets.
- This repo also includes a local `pre-push` hook that blocks direct pushes to `main` when `core.hooksPath` is configured.

## Local Guardrail

This repository includes `.githooks/pre-push` to block accidental pushes to `main`.

If your local clone is not already using it, run:

```powershell
git config core.hooksPath .githooks
```

To intentionally bypass the local guardrail for a one-off push:

```powershell
$env:ALLOW_MAIN_PUSH="1"
git push origin main
Remove-Item Env:ALLOW_MAIN_PUSH
```
