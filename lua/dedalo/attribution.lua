--- Joining what git says with what Dedalo would pay.
---
--- `git blame` gives an email per line. `dedalo contributors` gives a score
--- per email, and `dedalo identity list` says whether that email resolves to a
--- wallet. The interesting cell in that join is the one where somebody has a
--- score and no wallet: they wrote the code, the round would not pay them, and
--- nothing in the editor would otherwise say so.
local M = {}

local cli = require("dedalo.cli")
local config = require("dedalo.config")
local profile = require("dedalo.profile")

--- Cached per repository, keyed by `root .. HEAD`, because attribution changes
--- only when history does.
---@type table<string, table>
local cache = {}

--- Build `email -> { handle, share, linked, score }`.
---@param contributors table
---@param identities table
---@return table<string, table>
local function join(contributors, identities)
  local by_email = {}

  local total = tonumber(contributors.total_score) or 0
  for _, entry in ipairs(contributors.contributions or {}) do
    local email = (entry.author and entry.author.email or ""):lower()
    if email ~= "" then
      by_email[email] = {
        name = entry.author.name,
        score = entry.score,
        -- Per cent of the contributor pool this author's weight commands. Not
        -- an amount: the amount depends on the size of a round nobody has
        -- chosen yet.
        share = total > 0 and (tonumber(entry.score) or 0) / total * 100 or 0,
        merges = entry.merges,
        linked = false,
        handle = nil,
      }
    end
  end

  for _, identity in ipairs(identities or {}) do
    for _, email in ipairs(identity.emails or {}) do
      local key = email:lower()
      local found = by_email[key]
      if found then
        found.handle = identity.handle
        -- An excluded identity is deliberately unpaid — a bot, or a
        -- maintainer who opted out — which is not the same as unlinked, and
        -- the annotation should not imply someone forgot.
        found.linked = not identity.excluded
        found.excluded = identity.excluded == true
      end
    end
  end

  return by_email
end

--- Load attribution for `root`, from cache when history has not moved.
---
--- The commit at `HEAD` is handed back with the result rather than kept
--- private: the caller needs it to key its own cache, and reading it twice
--- would cost a subprocess to save passing an argument.
---@param root string
---@param on_done fun(by_email: table|nil, err: string|nil, head: string|nil)
function M.load(root, on_done)
  profile.stage("git rev-parse HEAD", function(finish)
    cli.run({ "git", "rev-parse", "HEAD" }, root, finish)
  end, function(head, err)
    if err then
      return on_done(nil, err, nil)
    end
    head = vim.trim(head)
    local key = root .. "@" .. head
    if cache[key] then
      profile.cached("dedalo contributors")
      profile.cached("dedalo identity list")
      return on_done(cache[key], nil, head)
    end

    local cmd = config.current.cmd
    profile.stage("dedalo contributors", function(finish)
      cli.run_json({ cmd, "contributors", "--json" }, root, finish)
    end, function(contributors, cerr)
      if cerr then
        return on_done(nil, cerr, nil)
      end
      profile.stage("dedalo identity list", function(finish)
        cli.run_json({ cmd, "identity", "list", "--json" }, root, finish)
      end, function(identities, ierr)
        if ierr then
          return on_done(nil, ierr, nil)
        end
        local joined = join(contributors, identities)
        cache[key] = joined
        on_done(joined, nil, head)
      end)
    end)
  end)
end

--- Drop everything cached. Exposed for `:DedaloRefresh` and for tests.
function M.clear_cache()
  cache = {}
end

--- The text and highlight for one blamed line.
---@param blamed table
---@param by_email table
---@return string label, string state
function M.label(blamed, by_email)
  if blamed.uncommitted then
    return "uncommitted — earns nothing yet", "uncommitted"
  end

  local entry = by_email[blamed.email]
  if entry == nil then
    -- Blamed to somebody with no contribution score: their work is outside
    -- the range the next round covers, usually because it is already paid.
    return ("%s — outside this round"):format(blamed.name ~= "" and blamed.name or blamed.email),
      "uncommitted"
  end

  local who = entry.handle or blamed.name
  if who == nil or who == "" then
    who = blamed.email
  end

  if entry.excluded then
    return ("%s — excluded from payouts"):format(who), "uncommitted"
  end

  local share = ""
  if entry.share >= config.current.min_share then
    share = (" · %.1f%%"):format(entry.share)
  end

  if entry.linked then
    return ("%s%s"):format(who, share), "linked"
  end
  return ("%s%s — no wallet, would not be paid"):format(who, share), "unlinked"
end

return M
