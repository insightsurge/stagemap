@AGENTS.md

## Claude Code

`AGENTS.md`, imported above, indexes the shared rules. Edit each rule in its topic file. Claude-only:

- `.claude/settings.json` denies force-push, pushes to `main`, `--no-verify` and hand edits to `NAMESPACE`, `man/`,
  `renv/` and `LICENSE`, makes `gh pr merge` ask for confirmation each time, and turns off attribution
  lines. It's a guard rail, not the gate; never work around it.
