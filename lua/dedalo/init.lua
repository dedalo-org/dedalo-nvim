--- Attribution where the code is.
---
--- Shows, next to the lines in front of you, who earns from them — read from
--- the same git history a Dedalo payout is computed from, and joined against
--- the wallets the project has on file.
---
--- The state worth having an editor for is the third one: an author with a
--- contribution score and no wallet. Dedalo puts them in `plan.unresolved`
--- and pays them nothing, and until now the only way to notice was to read a
--- payout plan.
local M = {}

local attribution = require("dedalo.attribution")
local blame = require("dedalo.blame")
local cli = require("dedalo.cli")
local config = require("dedalo.config")
local profile = require("dedalo.profile")
local render = require("dedalo.render")

---@type table<integer, boolean>
local attached = {}

--- Pending debounce timers, one per buffer.
---@type table<integer, uv.uv_timer_t>
local timers = {}

--- Stop and forget a buffer's pending timer.
---@param bufnr integer
local function cancel_timer(bufnr)
  local timer = timers[bufnr]
  if timer == nil then
    return
  end
  timer:stop()
  if not timer:is_closing() then
    timer:close()
  end
  timers[bufnr] = nil
end

--- Run `attach` for `bufnr` after `debounce_ms` of quiet.
---
--- `BufReadPost` fires once per buffer, so this is not about a chatty event —
--- it is about `:bufdo`, a session restore, and holding `]q` through a
--- quickfix list, each of which opens buffers faster than three subprocesses
--- can finish. Without it, walking twenty files spawns sixty processes for
--- nineteen answers nobody read.
---@param bufnr integer
---@param opts table
local function debounced_attach(bufnr, opts)
  local delay = config.current.debounce_ms or 0
  if delay <= 0 then
    return M.attach(bufnr, opts)
  end

  cancel_timer(bufnr)

  local timer = vim.uv.new_timer()
  timers[bufnr] = timer
  timer:start(
    delay,
    0,
    vim.schedule_wrap(function()
      cancel_timer(bufnr)
      -- The buffer may have been closed while the timer was pending.
      if vim.api.nvim_buf_is_valid(bufnr) then
        M.attach(bufnr, opts)
      end
    end)
  )
end

--- Configure the plugin. Optional: the defaults work.
---@param opts dedalo.Config|nil
function M.setup(opts)
  config.setup(opts)
  render.setup_highlights()

  if config.current.auto_attach then
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
      group = vim.api.nvim_create_augroup("dedalo.auto", { clear = true }),
      callback = function(event)
        -- Only where it can mean something. A scratch buffer, a help page or
        -- a repository without a dedalo.toml gets nothing.
        if vim.bo[event.buf].buftype ~= "" then
          return
        end
        debounced_attach(event.buf, { quiet = true })
      end,
    })
  end
end

--- Annotate one buffer.
---@param bufnr integer|nil Defaults to the current buffer.
---@param opts {quiet: boolean}|nil `quiet` suppresses "not a Dedalo project".
function M.attach(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  opts = opts or {}

  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    if not opts.quiet then
      vim.notify("dedalo: this buffer has no file", vim.log.levels.WARN)
    end
    return
  end

  local root = cli.repo_root(path)
  if root == nil then
    if not opts.quiet then
      vim.notify("dedalo: not inside a git repository", vim.log.levels.WARN)
    end
    return
  end
  if not cli.is_dedalo_project(root) then
    if not opts.quiet then
      vim.notify("dedalo: no dedalo.toml in " .. root, vim.log.levels.WARN)
    end
    return
  end

  attached[bufnr] = true
  profile.reset()

  attribution.load(root, function(by_email, err, head)
    if err then
      attached[bufnr] = nil
      if not opts.quiet then
        vim.notify("dedalo: " .. err, vim.log.levels.ERROR)
      end
      return
    end
    blame.of_file(root, path, head, function(lines, berr)
      if berr then
        attached[bufnr] = nil
        if not opts.quiet then
          vim.notify("dedalo: " .. berr, vim.log.levels.ERROR)
        end
        return
      end
      -- The buffer may have been closed while git was working.
      if not attached[bufnr] then
        return
      end
      render.apply(bufnr, lines, by_email)
    end)
  end)
end

--- Remove the annotation from one buffer.
---@param bufnr integer|nil
function M.detach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  cancel_timer(bufnr)
  attached[bufnr] = nil
  render.clear(bufnr)
end

--- Attach if detached, detach if attached.
---@param bufnr integer|nil
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if attached[bufnr] then
    M.detach(bufnr)
  else
    M.attach(bufnr)
  end
end

--- Forget what was cached and annotate again.
---
--- Attribution is cached against the commit at HEAD, so this is only needed
--- after something outside git changed — a `dedalo identity link`, or an edit
--- to `dedalo.toml`.
---@param bufnr integer|nil
function M.refresh(bufnr)
  attribution.clear_cache()
  blame.clear_cache()
  M.attach(bufnr)
end

--- What the last attach cost, as lines.
---
--- Exposed so "is it slow on my repository" is a question somebody can answer
--- for themselves rather than take our word for.
---@return string[]
function M.profile()
  return profile.report()
end

--- Whether `bufnr` is currently annotated. For tests and statuslines.
---@param bufnr integer|nil
---@return boolean
function M.is_attached(bufnr)
  return attached[bufnr or vim.api.nvim_get_current_buf()] == true
end

return M
