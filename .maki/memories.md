# Memories

## VCS backend (2026-10-05)

- `review.lua` supports both git and jj. Detection: `vcs_backend()` uses
  `maki.fs.root(cwd, ".jj")` (searches upward); if found, ONLY jj commands run.
- jj mapping: working-copy changes = `jj diff --summary` + `jj diff --git`
  (no `--numstat` in jj; adds/dels counted from git-format hunks by
  `apply_jj_stats`), log = `jj log --no-graph -r 'ancestors(@, 200)'` with
  `change_id.short()` (default `jj log` revset shows almost no history here),
  per-change files = `jj diff --summary/-git -r <id>`, commit info =
  `jj show --stat`, TurnEnd nudge = `jj diff --name-only`.
- Commit entries use field `rev` (git sha or jj change ID), comments store it
  in `commit`. jj renames parse as `R {old => new}` (keep new path); `A` covers
  snapshot-tracked new files, so jj has no untracked case.
- jj template for relative time: `self.committer().timestamp().ago()`
  (`format_time_relative` does not exist).
- Verified by harness in `_ignored/jjtest` (jj) and `_ignored/gittest` (git).
- Luau-only `continue` in `parse_diff`; syntax-check via luajit needs replacing
  it with `do end` first.
