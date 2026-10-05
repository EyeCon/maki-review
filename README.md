# maki-review

A [[maki](https://github.com/asaf/maki)](https://github.com/tontinton/maki) plugin that adds a `/review` command:
a TUI for reviewing maki's changes, leaving inline comments on diff lines,
and sending them back to maki — into the current session or a new one.

<img width="800" height="500" alt="recording2" src="https://github.com/user-attachments/assets/b84fb2dd-e995-4060-b15d-159d34f5d23a" />

## Features

- **Files** — changed files as a collapsible tree: vs `HEAD` (staged, unstaged,
  untracked) with git, or the working-copy change vs its parent with jj
- **Commits** — recent commits (git shas / jj change IDs); drill into a
  commit's files
- **Comments** — every review comment written so far
- **Diff pane** — syntax-highlighted diff with full-row tints; comment a line (`c`),
  select a range first (`v`), delete (`d`)
- **Submit** — `s` sends all comments to the current session, `S` to a new
  focused one; both address them
- After each turn, a status flash reminds you when files changed

## Keys

| Key | Action |
| --- | --- |
| `Tab` | cycle left panels |
| `Enter` / `l` | open dir / focus diff / open commit |
| `h` / `Esc` | collapse / back |
| `c` | comment on the current diff line |
| `v` | start range selection |
| `d` | delete comment |
| `s` | submit comments to this session |
| `S` | submit comments to a new session |
| `r` | refresh |
| `q` | quit |

## Git and jj

When a `.jj` directory marks the repository (searched upward from the working
directory), the plugin uses only [Jujutsu](https://jj-vcs.github.io/) commands
and identifies commits by change ID. Otherwise it falls back to git.

## Install

Copy `review.lua` into your maki plugins directory.

## Tests

`sh tests/run.sh` runs the parser and comment-logic suite against the real
plugin code (needs `luau` on `$PATH`; the maki host API is stubbed).
