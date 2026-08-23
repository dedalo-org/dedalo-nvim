--- Who wrote each line, from git.
local M = {}

local cli = require("dedalo.cli")

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
---@param root string
---@param path string
---@param on_done fun(lines: table|nil, err: string|nil)
function M.of_file(root, path, on_done)
  cli.run({ "git", "blame", "--line-porcelain", "--", path }, root, function(stdout, err)
    if err then
      return on_done(nil, err)
    end
    on_done(M.parse(stdout), nil)
  end)
end

return M
