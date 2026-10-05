#!/bin/sh
# Runs the review.lua test suite. The luau CLI gives every require() module
# an isolated environment, so the stubs (tests/prelude.luau), the plugin and
# the cases (tests/cases.luau) are stitched into a single chunk to share it.
set -e
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -t review_test.XXXXXX)
trap 'rm -f "$tmp"' EXIT INT TERM
{
  cat "$root/tests/prelude.luau"
  printf '\n'
  cat "$root/review.lua"
  printf '\n'
  cat "$root/tests/cases.luau"
} > "$tmp"
luau "$tmp"
