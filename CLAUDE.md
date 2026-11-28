@AGENTS.md

## Claude Code

- `.claude/settings.json` denies force-push, pushes to `main`, `--no-verify` and hand edits to `NAMESPACE`, `man/`,
  `renv/` and `LICENSE`, and makes `gh pr merge` ask each time. It's a guard rail, not the gate; never work around it.
