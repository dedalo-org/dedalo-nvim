--- Who wrote each line, from git.
local M = {}

local cli = require("dedalo.cli")
local profile = require("dedalo.profile")

--- Cached per `root@head:path`, for the same reason attribution is: blame of a
--- committed file changes only when history does.
---
--- The cache is deliberately keyed on the *file*, not the buffer. Two buffers
--- on the same file share an answer, and a buffer reopened after `:bd` does
--- not pay again.
---@type table<string, table>
local cache = {}

--- Parse `git blame --line-porcelain` into one author email per line.
---
--- Porcelain rather than the default format because the default puts the
--- author's *name* in the output, and Dedalo matches on email. Two people can
--- share a name; the identity mapping is keyed on the address.
---@param output string
---@return table<integer, {email: string, name: string, uncommitted: boolean}>
function M.parse(output)
  local lines = {}
  local current_line, name, email = nil, nil, nil

  for line in vim.gsplit(output, "\n", { plain = true }) do
    -- A header is `<sha> <orig-line> <final-line> [<count>]`.
    local sha, final = line:match("^(%x+)%s+%d+%s+(%d+)")
    if sha then
      current_line = tonumber(final)
      name, email = nil, nil
    elseif line:match("^author ") then
      name = line:sub(8)
    elseif line:match("^author%-mail ") then
      -- `author-mail <ada@example.com>`, angle brackets included.
      email = line:sub(13):gsub("^<", ""):gsub(">$", "")
    elseif line:match("^\t") and current_line then
      -- The tab-prefixed line is the source text, which closes the record.
      lines[current_line] = {
        name = name or "",
        email = (email or ""):lower(),
        -- Git reports not-yet-committed work under the all-zero sha. Those
        -- lines earn nothing yet, and saying so is the useful part.
        uncommitted = email == nil or email == "" or email == "not.committed.yet",
      }
      current_line = nil
    end
  end

  return lines
end

--- Blame `path`, relative to `root`.
---
--- `head` keys the cache. Pass the commit the caller already read — asking git
--- for it again here would cost a subprocess to save one.
---@param root string
---@param path string
---@param head string|nil Commit at HEAD; omit to skip the cache.
---@param on_done fun(lines: table|nil, err: string|nil)
function M.of_file(root, path, head, on_done)
  local key = head and (root .. "@" .. head .. ":" .. path) or nil
  if key and cache[key] then
    profile.cached("git blame")
    return on_done(cache[key], nil)
  end

  profile.stage("git blame", function(finish)
    cli.run({ "git", "blame", "--line-porcelain", "--", path }, root, finish)
  end, function(stdout, err)
    if err then
      return on_done(nil, err)
    end
    local parsed = M.parse(stdout)
    if key then
      cache[key] = parsed
    end
    on_done(parsed, nil)
  end)
end

--- Drop everything cached. Exposed for `:Dedalo refresh` and for tests.
function M.clear_cache()
  cache = {}
end

return M
