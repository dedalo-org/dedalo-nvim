--- Running `dedalo` and `git`, and reading what they say.
---
--- Everything here is asynchronous. Attribution is a nicety; blocking the
--- editor for it would be a poor trade, and `git blame` on a large file in a
--- large repository is not fast.
local M = {}

--- Run a command and hand its stdout to `on_done`.
---
--- `on_done(output, err)` receives exactly one of the two. It is called on the
--- main loop, so it may touch buffers.
---@param cmd string[]
---@param cwd string
---@param on_done fun(stdout: string|nil, err: string|nil)
function M.run(cmd, cwd, on_done)
  local ok, handle = pcall(vim.system, cmd, { text = true, cwd = cwd }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        -- stderr first: a CLI that failed explains itself there, and the
        -- message is the only thing the user will see in :checkhealth.
        local message = result.stderr
        if message == nil or message == "" then
          message = ("`%s` exited %d"):format(table.concat(cmd, " "), result.code)
        end
        on_done(nil, vim.trim(message))
        return
      end
      on_done(result.stdout, nil)
    end)
  end)

  if not ok then
    -- `vim.system` throws when the executable is not on PATH, rather than
    -- returning a non-zero exit, so the two failures need separate handling.
    vim.schedule(function()
      on_done(nil, ("cannot run `%s`: %s"):format(cmd[1], handle))
    end)
  end
end

--- Run a command and decode its stdout as JSON.
---@param cmd string[]
---@param cwd string
---@param on_done fun(value: any|nil, err: string|nil)
function M.run_json(cmd, cwd, on_done)
  M.run(cmd, cwd, function(stdout, err)
    if err then
      return on_done(nil, err)
    end
    local ok, decoded = pcall(vim.json.decode, stdout)
    if not ok then
      return on_done(nil, ("`%s` did not produce JSON"):format(table.concat(cmd, " ")))
    end
    on_done(decoded, nil)
  end)
end

--- The repository root containing `path`, or nil.
---
--- Synchronous on purpose: it is one `git rev-parse`, it decides whether any
--- of the rest is worth starting, and the answer is cached per buffer.
---@param path string
---@return string|nil
function M.repo_root(path)
  local dir = vim.fs.dirname(path)
  if dir == nil or dir == "" then
    return nil
  end
  local found = vim.fs.find(".git", { path = dir, upward = true, type = "directory" })[1]
    or vim.fs.find(".git", { path = dir, upward = true, type = "file" })[1]
  if found == nil then
    return nil
  end
  return vim.fs.dirname(found)
end

--- Whether `root` is a Dedalo project.
---@param root string
---@return boolean
function M.is_dedalo_project(root)
  return vim.uv.fs_stat(vim.fs.joinpath(root, "dedalo.toml")) ~= nil
end

return M
