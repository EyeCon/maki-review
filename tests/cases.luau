-- Test cases for review.lua. Stitched after the plugin by tests/run.sh, so
-- the plugin's chunk-locals are directly reachable. Golden fixtures are
-- captured from real git/jj output (format probes for -z listings, rename
-- spellings, C-quoting and merge diffs).

local assertions, failures = 0, 0

local function eq(actual, expected, name)
  assertions = assertions + 1
  if actual ~= expected then
    failures = failures + 1
    print(("FAIL %s\n  expected: %q\n  actual:   %q"):format(name, tostring(expected), tostring(actual)))
  end
end

local function ok(cond, name)
  eq(not not cond, true, name)
end

-- Flat "path|status|adds|dels|bin|untracked|commit" render of a change list.
local function dump_changes(list)
  local out = {}
  for _, ch in ipairs(list) do
    out[#out + 1] = table.concat({
      ch.path,
      ch.status,
      tostring(ch.adds),
      tostring(ch.dels),
      ch.binary and "bin" or "",
      ch.untracked and "untracked" or "",
      ch.commit or "",
    }, "|")
  end
  return table.concat(out, "\n")
end

-- Flat "kind|old|new|text" render of parsed diff lines.
local function dump_dlines(list)
  local out = {}
  for _, dl in ipairs(list) do
    out[#out + 1] = table.concat({
      dl.kind,
      tostring(dl.old_ln or "-"),
      tostring(dl.new_ln or "-"),
      dl.text,
    }, "|")
  end
  return table.concat(out, "\n")
end

--- fixtures (captured from real git/jj output) ------------------------------

local FIX_NAME_STATUS = "M\0bin.dat\0R100\0dir1/old name.txt\0dir1/new name.txt\0"
  .. "M\0plain.txt\0R100\0aaa/very/deep/old.txt\0zzz/other/new.txt\0"
  .. "D\0日本語.txt\0"

local FIX_NUMSTAT = "-\t-\tbin.dat\0"
  .. "3\t1\t\0dir1/old name.txt\0dir1/new name.txt\0"
  .. "1\t0\tplain.txt\0"
  .. "0\t0\t\0aaa/very/deep/old.txt\0zzz/other/new.txt\0"
  .. "0\t1\t日本語.txt\0"

local FIX_JJ_SUMMARY = 'R {a/x.txt => b/z.txt}\nM beta\nR dir1/{y.txt => y.log}\nM quo"te.txt\n'

local FIX_JJ_GIT = [==[
diff --git a/a/x.txt b/b/z.txt
rename from a/x.txt
rename to b/z.txt
diff --git a/beta b/beta
index 01058d844a..fb7e5aeed3 100644
--- a/beta
+++ b/beta
@@ -1,1 +1,2 @@
 g
+more
diff --git a/dir1/y.txt b/dir1/y.log
rename from dir1/y.txt
rename to dir1/y.log
diff --git a/quo"te.txt b/quo"te.txt
index 4bcfe98e64..cac73344cf 100644
Binary files a/quo"te.txt and b/quo"te.txt differ
]==]

local FIX_GIT_DIFF = [==[
diff --git a/bin.dat b/bin.dat
index 0e78043..dc7367e 100644
Binary files a/bin.dat and b/bin.dat differ
diff --git a/dir1/old name.txt b/dir1/new name.txt
similarity index 100%
rename from dir1/old name.txt
rename to dir1/new name.txt
diff --git a/plain.txt b/plain.txt
index 7898192..21b4900 100644
--- a/plain.txt
+++ b/plain.txt
@@ -1 +1,2 @@
 a
+mod
diff --git a/with space.txt b/with space.txt
index 6178079..5794df8 100644
--- a/with space.txt
+++ b/with space.txt
@@ -1 +1,2 @@
 b
+mod
diff --git "a/\346\227\245\346\234\254\350\252\236.txt" "b/\346\227\245\346\234\254\350\252\236.txt"
deleted file mode 100644
index 6a69f92..0000000
--- "a/\346\227\245\346\234\254\350\252\236.txt"
+++ /dev/null
@@ -1 +0,0 @@
-f
]==]

--- run (exit codes) --------------------------------------------------------

canned = {
  { cmd = "exit-zero", out = "hello\n" },
  { cmd = "exit-one", exit = 1, err = "  boom  " },
  { cmd = "no-index", exit = 1, out = "a diff" },
  { cmd = "exit-two", exit = 2 },
  { cmd = "never", wait_nil = true },
}
eq((run("exit-zero")), "hello\n", "run: exit 0 returns stdout")
local out, err = run("exit-one")
eq(out, nil, "run: exit 1 fails by default")
eq(err, "boom", "run: exit 1 surfaces trimmed stderr")
eq((run("no-index", true)), "a diff", "run: allow_one tolerates exit 1")
out, err = run("exit-two")
eq(out, nil, "run: exit 2 fails")
eq(err, "exit 2", "run: empty stderr falls back to exit code")
eq(run("never"), nil, "run: jobwait nil times out")
ok(select(2, run("never")):find("timed out", 1, true) ~= nil, "run: timeout message")

--- split0 ------------------------------------------------------------------

local toks = split0("a\0bb\0ccc\0")
eq(#toks, 3, "split0: token count")
eq(toks[3], "ccc", "split0: last token")
eq(#split0(""), 0, "split0: empty input")
eq(#split0("\0\0"), 0, "split0: empty tokens dropped")

--- unquote_git_path --------------------------------------------------------

eq(unquote_git_path([["\346\227\245\346\234\254\350\252\236.txt"]]), "日本語.txt", "unquote: octal UTF-8 bytes")
eq(unquote_git_path([["back\\slash.txt"]]), "back\\slash.txt", "unquote: escaped backslash")
eq(unquote_git_path([["back\\303"]]), "back\\303", "unquote: escaped backslash before digits")
eq(unquote_git_path([["quo\"te.txt"]]), 'quo"te.txt', "unquote: escaped quote")
eq(unquote_git_path([["tab\there"]]), "tab\there", "unquote: escaped tab")
eq(unquote_git_path("plain.txt"), "plain.txt", "unquote: unquoted passthrough")

--- git listing parsers -----------------------------------------------------

local changes, seen = {}, {}
apply_name_status(changes, seen, FIX_NAME_STATUS, "rev1")
eq(#changes, 5, "name-status: entry count")
eq(changes[2].path, "dir1/new name.txt", "name-status: rename keeps new path")
eq(changes[2].status, "R", "name-status: rename status")
eq(changes[5].path, "日本語.txt", "name-status: unicode path is raw")
eq(changes[1].commit, "rev1", "name-status: commit field set")

apply_numstat(changes, seen, FIX_NUMSTAT)
eq(changes[1].binary, true, "numstat: binary flag")
eq(changes[2].adds .. "/" .. changes[2].dels, "3/1", "numstat: rename gets stats")
eq(changes[3].adds .. "/" .. changes[3].dels, "1/0", "numstat: plain stats")
eq(changes[5].adds .. "/" .. changes[5].dels, "0/1", "numstat: unicode stats")

-- jj summary rename spellings (prefix factored out, names may hold " => ").
eq(jj_new_path("dir1/{old name.txt => new name.txt}"), "dir1/new name.txt", "jj rename: shared prefix")
eq(jj_new_path("{a/x.txt => b/z.txt}"), "b/z.txt", "jj rename: cross-directory")
eq(jj_new_path("dir1/{y.txt => y.log}"), "dir1/y.log", "jj rename: shared suffix form")
eq(jj_new_path("{plain.txt => weird => name.txt}"), "weird => name.txt", "jj rename: arrow in name")
eq(jj_new_path("plain.txt"), "plain.txt", "jj rename: non-rename passthrough")
eq(jj_new_path("dir1/{y.txt => y.log"), "dir1/{y.txt => y.log", "jj rename: unclosed brace")

-- jj git-format stats over the summary's changes.
changes, seen = {}, {}
for line in FIX_JJ_SUMMARY:gmatch("[^\n]+") do
  local status, rest = line:match("^(%S)%s+(.+)$")
  local path = jj_new_path(rest)
  seen[path] = #changes + 1
  changes[#changes + 1] = { path = path, status = status, adds = 0, dels = 0 }
end
apply_jj_stats(changes, seen, FIX_JJ_GIT)
eq(changes[2].adds .. "/" .. changes[2].dels, "1/0", "jj stats: hunk counted")
eq(changes[4].binary, true, "jj stats: binary marker")
eq(changes[1].adds .. "/" .. changes[1].dels, "0/0", "jj stats: pure rename stays zero")

--- parse_log ---------------------------------------------------------------

local log = parse_log("abc123\tsubj\twith\ttab\t2 hours ago\nzz9\tplain\tnow\nq\tx\t\n")
eq(#log, 3, "log: line count")
eq(log[1].subject, "subj\twith\ttab", "log: subject keeps tabs")
eq(log[1].when, "2 hours ago", "log: when is the last field")
eq(log[2].rev, "zz9", "log: plain line")
eq(log[3].subject, "x", "log: empty when")

--- parse_diff --------------------------------------------------------------

eq(dump_dlines(parse_diff(FIX_GIT_DIFF)),
  "hunk|-|-|@@ -1 +1,2 @@\n"
  .. "ctx|1|1|a\n"
  .. "add|-|2|mod\n"
  .. "hunk|-|-|@@ -1 +1,2 @@\n"
  .. "ctx|1|1|b\n"
  .. "add|-|2|mod\n"
  .. "hunk|-|-|@@ -1 +0,0 @@\n"
  .. "del|1|-|f",
  "parse_diff: multi-file golden (binary, rename, unicode delete)")

eq(dump_dlines(parse_diff([==[
diff --git a/x b/x
index 1111111..2222222 100644
--- a/x
+++ b/x
@@ -1 +1 @@
-a
\ No newline at end of file
+b
\ No newline at end of file
]==])),
  "hunk|-|-|@@ -1 +1 @@\n"
  .. "del|1|-|a\n"
  .. "add|-|1|b",
  "parse_diff: no-newline markers dropped")

eq(#parse_diff(""), 0, "parse_diff: empty input")

--- comments ----------------------------------------------------------------

local dlines = {
  { kind = "hunk", text = "@@ -1,3 +1,3 @@" },
  { kind = "ctx", text = "a", old_ln = 1, new_ln = 1 },
  { kind = "del", text = "b", old_ln = 2 },
  { kind = "add", text = "b2", new_ln = 2 },
  { kind = "ctx", text = "c", old_ln = 3, new_ln = 3 },
  { kind = "hunk", text = "@@ -20,2 +20,2 @@" },
  { kind = "del", text = "z", old_ln = 20 },
  { kind = "add", text = "z2", new_ln = 21 },
}
local change = { path = "f" }
local c = make_comment(change, dlines, 3, 8, "x")
eq(c.anchor, "new", "comment: anchored on last non-hunk row")
ok(c.new_lines[2] and c.new_lines[3] and c.new_lines[21], "comment: new-side set")
ok(c.old_lines[2] and c.old_lines[3] and c.old_lines[20], "comment: old-side set")
ok(not covers(c, dlines[1]), "comment: hunk row not covered")
ok(covers(c, dlines[7]), "comment: second-hunk line covered")
ok(not covers(c, { kind = "del", text = "q", old_ln = 5 }),
  "comment: unselected line in covered range NOT covered")
ok(c.snippet:find("@@ -20,2 +20,2 @@", 1, true) ~= nil, "comment: snippet keeps in-range hunk header")
ok(c.snippet:find("<<< comment applies here", 1, true) ~= nil, "comment: snippet marks selection")
eq(line_range_label(c), "lines 2-3, 21", "label: multi-run new side")
c.anchor = "old"
eq(line_range_label(c), "removed lines 2-3, 20", "label: multi-run old side")

local c2 = make_comment(change, dlines, 3, 6, "x")
eq(c2.anchor, "new", "label: range ending on hunk row anchors on diff line")
eq(line_range_label(c2), "lines 2-3", "label: hunk-end range")

local c3 = make_comment(change, dlines, 3, 3, "x")
eq(line_range_label(c3), "removed line 2", "label: single removed line")

comments[#comments + 1] = c
ok(comment_at(change, dlines[7]) == c, "comment_at: finds comment")
ok(comment_at(change, dlines[1]) == nil, "comment_at: hunk row has none")
ok(comment_in_range(change, dlines, 7, 8) == c, "comment_in_range: overlap found")
eq(comment_count(change), 1, "comment_count: one comment")
comments[#comments] = nil

--- wrap / fit_path / sanitize_utf8 -----------------------------------------

eq(table.concat(wrap("aaa bbb ccc", 7), "\n"), "aaa bbb\nccc", "wrap: greedy fill at width")
eq(table.concat(wrap("hello wonderful world", 11), "\n"), "hello\nwonderful\nworld", "wrap: breaks mid-word at last space")
eq(table.concat(wrap("x" .. string.rep("y", 22), 10), "\n"), "xyyyyyyyyy\nyyyyyyyyyy\nyyy", "wrap: hard cut long word")
eq(table.concat(wrap("a\n\nb", 10), "\n"), "a\n\nb", "wrap: preserves empty lines")
local wide = wrap("日本語日本語", 4)
eq(table.concat(wide, "\n"), "日本語日\n本語", "wrap: wide text")
ok(utf8.len(wide[1]) ~= nil and utf8.len(wide[2]) ~= nil, "wrap: never splits a character")

eq(fit_path("short", 10), "short", "fit_path: passthrough")
eq(fit_path("aaaaaaaaaa", 5), "…aaaa", "fit_path: keeps the tail")
local cut = fit_path("日本語日本語", 4)
eq(display_len(cut), 4, "fit_path: fits width")
ok(utf8.len(cut) ~= nil, "fit_path: character boundary")

eq(sanitize_utf8("héllo"), "héllo", "sanitize: valid passthrough")
eq(sanitize_utf8("\255abc"), "abc", "sanitize: invalid byte dropped")
eq(sanitize_utf8(""), "", "sanitize: empty")
eq(sanitize_utf8(nil), nil, "sanitize: nil")

--- git_changes / jj_changes (stubbed commands) ------------------------------

canned = {
  { cmd = "rev-parse", out = "true\n" },
  { cmd = "name-status", out = FIX_NAME_STATUS },
  { cmd = "numstat", out = FIX_NUMSTAT },
  { cmd = "ls-files", out = "un tracked?.txt\0" },
}
eq(dump_changes(git_changes()),
  "bin.dat|M|0|0|bin||\n"
  .. "dir1/new name.txt|R|3|1|||\n"
  .. "plain.txt|M|1|0|||\n"
  .. "un tracked?.txt|?|0|0||untracked|\n"
  .. "zzz/other/new.txt|R|0|0|||\n"
  .. "日本語.txt|D|0|1|||",
  "git_changes: sorted golden list")

canned = {
  { cmd = "summary", out = FIX_JJ_SUMMARY },
  { cmd = "jj diff --git", out = FIX_JJ_GIT },
}
eq(dump_changes(jj_changes()),
  'b/z.txt|R|0|0|||\n'
  .. "beta|M|1|0|||\n"
  .. "dir1/y.log|R|0|0|||\n"
  .. 'quo"te.txt|M|0|0|bin||',
  "jj_changes: sorted golden list")

canned = {
  { cmd = "rev-parse", out = "true\n" },
  { cmd = "name-status", exit = 1, err = "fatal: bad revision" },
}
local list, gerr = git_changes()
eq(list, nil, "git_changes: command failure propagates")
eq(gerr, "fatal: bad revision", "git_changes: error message")

canned = {
  { cmd = "summary", exit = 1, err = "Error: revision not found" },
}
list, gerr = jj_changes()
eq(list, nil, "jj_changes: jj exit 1 is an error")
ok(gerr:find("revision not found", 1, true) ~= nil, "jj_changes: error message")

print(("%d assertion(s), %d failure(s)"):format(assertions, failures))
if failures > 0 then
  error(failures .. " test failure(s)")
end
