# Memories

## Layout (2026-10-05)

- `review.lua` must stay a single self-contained file (README: users copy it
  into their maki plugins dir); do not split it into modules. Tests stitch
  it in (see Testing) instead of needing a test seam.
- An identical copy is installed at `~/.config/maki/lua/review.lua`; keep
  the two copies byte-identical.

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
  in `commit`. jj renames parse as `R prefix/{old name => new name}` (shared
  dir prefix outside braces, names may contain ` => `); `jj_new_path`
  reconstructs the full new path. `A` covers snapshot-tracked new files, so jj
  has no untracked case. jj paths in `diff --git` headers are raw (unquoted).
- jj template for relative time: `self.committer().timestamp().ago()`
  (`format_time_relative` does not exist).

## git parsing (2026-10-05)

- All git listings use `-z` NUL output (raw paths, no C-quoting):
  `name-status -z` is `status\0path\0` (renames `status\0old\0new\0`),
  `numstat -z` is `adds\tdels\tpath\0` (renames have an empty path field then
  `old\0new\0`). Split with `split0`.
- Merge commits need `--diff-merges=first-parent` (diff-tree/show print
  nothing for merges otherwise); root commits need `--root` on diff-tree.
- `run(cmd, allow_one)` is strict about exit codes; only `git diff --no-index`
  passes `allow_one` (exit 1 = files differ).

## Comment records (2026-10-05)

- `old_lines`/`new_lines` are exact sets of covered file line numbers per
  side (min/max ranges over-match across `@@` hunks). `anchor` is "old" for
  removed lines, "new" otherwise; `line_range_label` renders contiguous runs.
- `win:recv` key events use canonical notation (`<CR>`, `<Esc>`, `<Up>`...),
  never the deprecated `enter`/`esc`/`ctrl+n` spellings.

## Testing (2026-10-05)

- `sh tests/run.sh` runs `tests/cases.luau` (81 assertions; golden fixtures
  captured from real git/jj output). The luau CLI gives every `require()`
  module an isolated environment, so run.sh stitches `tests/prelude.luau` +
  `review.lua` + `tests/cases.luau` into one chunk to share the `maki`/`require`
  stubs. review.lua needs no test seam: its chunk-locals are reachable.
- Syntax-check with `~/.binaries/luau-analyze` (handles Luau `continue`;
  `Unknown global 'maki'` warnings are expected).

## Luau gotchas (2026-10-05)

- `utf8.len` returns `nil` on invalid input (does not error): check the
  result, not just `pcall` success.
- `utf8.charpattern`/`gmatch` misbehaves on binary input (can hang); sanitize
  with byte-level lead/continuation checks + `utf8.len(seq)` validation.
- `maki.ui.truncate_text(s, max)` returns `{head, tail}` split at display-cell
  boundaries; `maki.ui.display_width` measures cells (use instead of
  `utf8.len`, which counts characters).
