--- `:checkhealth dedalo`.
---
--- Everything this plugin does depends on two executables and one file. When
--- the annotation does not appear, the cause is almost always one of them, and
--- a health check is cheaper than reading source.
local M = {}

local config = require("dedalo.config")

--- The oldest `dedalo` whose `--json` output this plugin can read.
---
--- The plugin parses `dedalo contributors --json` and
--- `dedalo identity list --json`, and those shapes are a contract in the main
--- repository: renaming a field there breaks this plugin silently, and a
--- silent break here tells somebody the author in front of them *would be
--- paid* when they would not. So the version is checked rather than hoped for.
---
--- `0.0.1` because `0.0.0` is a placeholder that holds the name on crates.io
--- and contains no code.
M.minimum_dedalo = "0.0.1"

local function version_of(cmd)
  local result = vim.system({ cmd, "--version" }, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.trim(result.stdout)
end

--- Pull `1.2.3` out of whatever `--version` printed.
---@param text string|nil
---@return integer[]|nil
local function semver(text)
  if text == nil then
    return nil
  end
  local major, minor, patch = text:match("(%d+)%.(%d+)%.(%d+)")
  if major == nil then
    return nil
  end
  return { tonumber(major), tonumber(minor), tonumber(patch) }
end

--- Whether `found` is at least `wanted`.
---@param found integer[]
---@param wanted integer[]
---@return boolean
local function at_least(found, wanted)
  for index = 1, 3 do
    if found[index] ~= wanted[index] then
      return found[index] > wanted[index]
    end
  end
  return true
end

function M.check()
  vim.health.start("dedalo.nvim")

  -- First, because it is the first thing to put in a bug report and the last
  -- thing anybody can work out for themselves: plugin managers pin by tag, and
  -- "latest" is not an answer.
  vim.health.info("dedalo.nvim " .. require("dedalo.version"))

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
    local reported = version_of(cmd)
    local found = semver(reported)
    local wanted = semver(M.minimum_dedalo)

    if found == nil then
      -- Not an error: a locally built binary can print something unexpected,
      -- and refusing to work over it would be worse than saying so.
      vim.health.warn(
        ("%s: %s — cannot read a version from that"):format(cmd, reported or "found"),
        {
          "This plugin needs dedalo " .. M.minimum_dedalo .. " or newer.",
        }
      )
    elseif at_least(found, wanted) then
      vim.health.ok(("%s: %s (needs %s or newer)"):format(cmd, reported, M.minimum_dedalo))
    else
      vim.health.error(("%s: %s is older than %s"):format(cmd, reported, M.minimum_dedalo), {
        "The --json shape this plugin reads is a contract, and older versions",
        "predate it. An annotation built from the wrong shape can say somebody",
        "would be paid when they would not.",
        "cargo install dedalo --locked",
      })
    end
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
