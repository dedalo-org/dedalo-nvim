--- Defaults, and the one function that merges a user's table into them.
local M = {}

---@class dedalo.Config
---@field cmd string Executable to run. Looked up on PATH.
---@field auto_attach boolean Show attribution as soon as a buffer in a Dedalo project is opened.
---@field debounce_ms integer Quiet period before an auto-attach runs, in milliseconds.
---@field min_share number Hide a contributor whose share of the round is below this, in per cent.
---@field virt_text_pos string Where the annotation sits: "eol", "right_align" or "inline".
---@field highlights table<string, string> Highlight group per state.
---@field icons table<string, string> Prefix per state.
M.defaults = {
  cmd = "dedalo",

  -- Off by default. A plugin that shells out to git blame and a CLI on every
  -- BufEnter, in every repository, without being asked, is a plugin people
  -- uninstall.
  auto_attach = false,

  -- Quiet period before an auto-attach fires. `BufReadPost` is not a chatty
  -- event, but `:bufdo`, a session restore and holding `]q` through a quickfix
  -- list all open buffers faster than three subprocesses can finish. Set to 0
  -- to attach immediately.
  debounce_ms = 150,

  -- Below a tenth of a per cent the number says nothing and the annotation is
  -- noise. The author is still shown; only the share is dropped.
  min_share = 0.1,

  virt_text_pos = "eol",

  highlights = {
    linked = "DedaloLinked",
    unlinked = "DedaloUnlinked",
    uncommitted = "DedaloUncommitted",
  },

  icons = {
    linked = "▏",
    unlinked = "▏",
    uncommitted = "▏",
  },
}

---@type dedalo.Config
M.current = vim.deepcopy(M.defaults)

--- Merge `opts` over the defaults.
---@param opts dedalo.Config|nil
function M.setup(opts)
  M.current = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.current
end

return M
