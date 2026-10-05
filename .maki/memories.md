# Memories

## Layout (2026-10-05)

- `review.lua` must stay a single self-contained file (README: users copy it
  into their maki plugins dir); do not split it into modules. Tests stitch
  it in (see Testing) instead of needing a test seam.
- An identical copy is installed at `~/.config/maki/lua/review.lua`; the two
  are hardlinked, so edits apply to both (no explicit sync).

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
- `win:recv` key events use canonical notation (`<CR>`, `<Esc>`, `<Up>...`),
  never the deprecated `enter`/`esc`/`ctrl+n` spellings.

## Submit targets (2026-10-05)

- `submit(state, target)`: `s` key = `"current"` → `maki.session.prompt` to
  the session the review runs in (`state.host`, captured via
  `maki.session.current()` in `open_review`; omit the `session` field when
  nil), `S` key = `"new"` → `maki.session.new({prompt, focus})`. `prompt`
  returns "started"/"queued"; queued gets a " (queued)" flash suffix.
- The prompt preamble intentionally has NO per-rev framing: one review can
  cover many changes/commits (per-comment `commit <rev>` labels identify
  them). The jj note ("All VCS operations ... never git.") is included when
  `vcs_backend() == "jj"`.

## Testing (2026-10-05)

- `sh tests/run.sh` runs `tests/cases.luau` (114 assertions; golden fixtures
  captured from real git/jj output). The luau CLI gives every `require()`
  module an isolated environment, so run.sh stitches `tests/prelude.luau` +
  `review.lua` + `tests/cases.luau` into one chunk to share the `maki`/`require`
  stubs. review.lua needs no test seam: its chunk-locals are reachable.
  Stub state: `canned`/`ran_cmds` (shell), `session_results`/`session_calls`
  (maki.session), `flashes` (maki.ui.flash).
- Syntax-check with `~/.binaries/luau-analyze` (handles Luau `continue`;
  `Unknown global 'maki'` warnings are expected).

## Float chrome / pane widths (2026-10-05)

- maki widens a bordered float to fit its title and footer:
  `float_width = max(configured, max(title_w, footer_w) + 2)` (BORDER_CELLS=2,
  hint_footer renders `" key label"` per pair + one trailing space). A float
  only stays at its configured width when title/footer fit `width - 2`, or
  the active pane's wider hints pull its border past its neighbours.
- `win.width` returns the configured width (`init_width`), NOT the widened
  one. Fix: `hint_width`/`fit_hints`/`ellipmid` in review.lua fit title and
  footer into `pane_width - 2` before `set_config` (labels middle-ellipsized
  to a 5-cell floor, then trailing pairs dropped). Footer labels are kept
  short ("here N"/"new N") so the widest pane footer fits the 46-col cap.

## Luau gotchas (2026-10-05)

- `utf8.len` returns `nil` on invalid input (does not error): check the
  result, not just `pcall` success.
- `utf8.charpattern`/`gmatch` misbehaves on binary input (can hang); sanitize
  with byte-level lead/continuation checks + `utf8.len(seq)` validation.
- `maki.ui.truncate_text(s, max)` returns `{head, tail}` split at display-cell
  boundaries; `maki.ui.display_width` measures cells (use instead of
  `utf8.len`, which counts characters).
