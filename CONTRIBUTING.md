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

## Recommended GitHub Rule For `main`

Configure a branch protection rule or ruleset for `main` with:

- Require a pull request before merging
- Require status checks to pass before merging
- Required status check: `build-android`
- Block force pushes
- Optionally require conversation resolution before merging

GitHub docs:

- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches
- https://docs.github.com/github/administering-a-repository/enabling-force-pushes-to-a-protected-branch
