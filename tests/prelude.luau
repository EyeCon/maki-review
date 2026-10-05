-- Test prelude: stubs of the maki host API so review.lua can run outside
-- maki. tests/run.sh stitches this, review.lua and tests/cases.luau into a
-- single chunk: the luau CLI gives every require() module an isolated
-- environment, so stubs and plugin code must share one.

local real_require = require
local function noop() end

-- Canned results for maki.fn.jobwait, matched by substring of the command:
-- { cmd = "numstat", exit = 0, out = "...", err = "..." } (exit defaults 0).
local canned = {}
local ran_cmds = {}

-- Canned (value, err) results for the maki.session stubs, keyed by function
-- name ("current" | "new" | "prompt"); session_calls records every call as
-- { fn, text?, opts? } in call order. flashes collects maki.ui.flash texts.
local session_results = {
  current = { "sess-1" },
  new = { "new-1" },
  prompt = { "started" },
}
local session_calls = {}
local flashes = {}

maki = {
  api = {
    register_command = noop,
    create_autocmd = noop,
  },
  log = { debug = noop, info = noop, warn = noop, error = noop },
  ui = {
    flash = function(msg)
      flashes[#flashes + 1] = msg
    end,
    display_width = function(s)
      local ok, n = pcall(utf8.len, s)
      return (ok and n) or #s
    end,
    -- Cell-boundary split; the stub counts one cell per character.
    truncate_text = function(s, max)
      local head, w = {}, 0
      for ch in s:gmatch(utf8.charpattern) do
        if w + 1 > max then
          break
        end
        head[#head + 1] = ch
        w = w + 1
      end
      local h = table.concat(head)
      return { head = h, tail = s:sub(#h + 1) }
    end,
    theme_style = function()
      return nil
    end,
  },
  fn = {
    jobstart = function(cmd)
      ran_cmds[#ran_cmds + 1] = cmd
      return #ran_cmds
    end,
    jobwait = function(id)
      local cmd = ran_cmds[id]
      for _, c in ipairs(canned) do
        if cmd:find(c.cmd, 1, true) then
          if c.wait_nil then
            return nil
          end
          return {
            exit_code = c.exit or 0,
            stdout = c.out or "",
            stderr = c.err or "",
          }
        end
      end
      return { exit_code = 0, stdout = "", stderr = "" }
    end,
  },
  fs = { root = function() return nil end },
  uv = { cwd = function() return "." end },
  session = {
    current = function()
      session_calls[#session_calls + 1] = { fn = "current" }
      local r = session_results.current or {}
      return r[1], r[2]
    end,
    new = function(opts)
      session_calls[#session_calls + 1] = { fn = "new", opts = opts }
      local r = session_results.new or {}
      return r[1], r[2]
    end,
    prompt = function(text, opts)
      session_calls[#session_calls + 1] = { fn = "prompt", text = text, opts = opts }
      local r = session_results.prompt or {}
      return r[1], r[2]
    end,
  },
}

require = function(name)
  if name == "maki.text_input" then
    return {
      Result = { IGNORED = "ignored", MOVED = "moved", CHANGED = "changed" },
      new = function() end,
    }
  end
  return real_require(name)
end
