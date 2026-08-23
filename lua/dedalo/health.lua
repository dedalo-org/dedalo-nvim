--- `:checkhealth dedalo`.
---
--- Everything this plugin does depends on two executables and one file. When
--- the annotation does not appear, the cause is almost always one of them, and
--- a health check is cheaper than reading source.
local M = {}

local config = require("dedalo.config")

local function version_of(cmd)
  local result = vim.system({ cmd, "--version" }, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.trim(result.stdout)
end

function M.check()
  vim.health.start("dedalo.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim " .. tostring(vim.version()))
  else
    vim.health.error("Neovim 0.10 or newer is required")
  end

  if vim.fn.executable("git") == 1 then
    vim.health.ok("git: " .. (version_of("git") or "found"))
  else
    vim.health.error("git is not on PATH", { "Attribution is read from git blame." })
  end

  local cmd = config.current.cmd
  if vim.fn.executable(cmd) == 1 then
    vim.health.ok(("%s: %s"):format(cmd, version_of(cmd) or "found"))
  else
    vim.health.error(("`%s` is not on PATH"):format(cmd), {
      "cargo install dedalo --locked",
      "or set `cmd` in setup() to its path",
    })
  end

  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.health.info("open a file in a project to check the rest")
    return
  end

  local cli = require("dedalo.cli")
  local root = cli.repo_root(path)
  if root == nil then
    vim.health.warn("the current file is not inside a git repository")
    return
  end
  vim.health.ok("repository: " .. root)

  if cli.is_dedalo_project(root) then
    vim.health.ok("dedalo.toml found")
  else
    vim.health.warn("no dedalo.toml in " .. root, {
      "This plugin annotates Dedalo projects. Run `dedalo init` to create one.",
    })
  end
end

return M
