-- A test runner in forty lines, because a plugin this size should not need a
-- test framework as a dependency to prove it works.
local failures, passed = {}, 0

local function check(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    io.write("  ok    " .. name .. "\n")
  else
    table.insert(failures, name)
    io.write("  FAIL  " .. name .. "\n        " .. tostring(err) .. "\n")
  end
end

local function eq(actual, expected, what)
  if actual ~= expected then
    error(
      ("%s: expected %s, got %s"):format(
        what or "value",
        vim.inspect(expected),
        vim.inspect(actual)
      ),
      2
    )
  end
end

local function contains(haystack, needle)
  if not tostring(haystack):find(needle, 1, true) then
    error(("expected %s to contain %q"):format(vim.inspect(haystack), needle), 2)
  end
end

-- ---------------------------------------------------------------- blame ---

local blame = require("dedalo.blame")

check("blame parses one author per line", function()
  local output = table.concat({
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 1 1 2",
    "author Ada",
    "author-mail <Ada@Example.com>",
    "\tfirst line",
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 2 2",
    "author Ada",
    "author-mail <Ada@Example.com>",
    "\tsecond line",
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb 3 3 1",
    "author Bea",
    "author-mail <bea@example.com>",
    "\tthird line",
  }, "\n")
  local lines = blame.parse(output)
  eq(lines[1].email, "ada@example.com", "line 1 email is lowercased")
  eq(lines[2].email, "ada@example.com", "line 2")
  eq(lines[3].email, "bea@example.com", "line 3")
  eq(lines[1].uncommitted, false, "committed")
end)

check("blame marks not-yet-committed lines", function()
  local output = table.concat({
    "0000000000000000000000000000000000000000 1 1 1",
    "author Not Committed Yet",
    "author-mail <not.committed.yet>",
    "\tnew line",
  }, "\n")
  local lines = blame.parse(output)
  eq(lines[1].uncommitted, true, "uncommitted")
end)

-- ---------------------------------------------------------- attribution ---

local attribution = require("dedalo.attribution")
require("dedalo.config").setup({})

local by_email = {
  ["ada@example.com"] = { name = "Ada", handle = "ada", share = 50.25, linked = true },
  ["bea@example.com"] = { name = "Bea", handle = nil, share = 49.75, linked = false },
  ["bot@example.com"] = {
    name = "Bot",
    handle = "bot",
    share = 0,
    linked = false,
    excluded = true,
  },
}

check("a linked contributor shows handle and share", function()
  local label, state = attribution.label({ email = "ada@example.com", name = "Ada" }, by_email)
  eq(state, "linked", "state")
  contains(label, "ada")
  contains(label, "50.2")
end)

check("an unlinked contributor says they would not be paid", function()
  local label, state = attribution.label({ email = "bea@example.com", name = "Bea" }, by_email)
  eq(state, "unlinked", "state")
  contains(label, "no wallet")
end)

check("an excluded identity is not reported as a mistake", function()
  local label, state = attribution.label({ email = "bot@example.com", name = "Bot" }, by_email)
  eq(state, "uncommitted", "excluded is not a warning")
  contains(label, "excluded")
end)

check("an author outside the round says so", function()
  local label = attribution.label({ email = "old@example.com", name = "Old" }, by_email)
  contains(label, "outside this round")
end)

check("uncommitted work earns nothing yet", function()
  local label, state = attribution.label({ uncommitted = true, email = "", name = "" }, by_email)
  eq(state, "uncommitted", "state")
  contains(label, "earns nothing yet")
end)

-- ------------------------------------------------- being wrong is worse ---
--
-- The states where a wrong answer costs more than no answer. This plugin's
-- whole purpose is telling somebody the author in front of them **would not be
-- paid**; a stack trace, a stale annotation, or an error per redraw are each
-- worse than saying nothing.
--
-- `dedalo` is faked here and git is not. Faking git would test the fake — its
-- output is what the parser exists to read. What matters about `dedalo` is not
-- what it computes but what happens when it is absent, slow or wrong, and
-- those are not states a real binary can be asked to be in.

local dedalo = require("dedalo")
local render = require("dedalo.render")

local FAKE = vim.fn.getcwd() .. "/tests/fake/dedalo"

--- Run `fn` with the fake in a given mode, then put the world back.
local function with_fake(mode, fn)
  local previous = vim.env.FAKE_DEDALO_MODE
  vim.env.FAKE_DEDALO_MODE = mode
  local ok, err = pcall(fn)
  vim.env.FAKE_DEDALO_MODE = previous
  if not ok then
    error(err, 0)
  end
end

--- Collect everything `vim.notify` is told, for as long as `fn` runs.
local function notifications(fn)
  local seen = {}
  local original = vim.notify
  vim.notify = function(message, level)
    table.insert(seen, { message = message, level = level })
  end
  local ok, err = pcall(fn)
  vim.notify = original
  if not ok then
    error(err, 0)
  end
  return seen
end

--- A throwaway git repository, optionally a Dedalo project.
local function temp_repo(with_config)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  vim.fn.system({ "git", "-C", dir, "init", "-q", "-b", "main" })
  vim.fn.system({ "git", "-C", dir, "config", "user.email", "t@example.com" })
  vim.fn.system({ "git", "-C", dir, "config", "user.name", "T" })
  vim.fn.writefile({ "one", "two" }, dir .. "/f.txt")
  vim.fn.system({ "git", "-C", dir, "add", "-A" })
  vim.fn.system({ "git", "-C", dir, "commit", "-qm", "first" })
  if with_config then
    vim.fn.writefile({ "[project]", 'name = "demo"' }, dir .. "/dedalo.toml")
  end
  return dir
end

local function marks_on(bufnr)
  return #vim.api.nvim_buf_get_extmarks(bufnr, render.namespace, 0, -1, {})
end

--- Open a file and return its buffer, with the annotation cleared.
local function open(path)
  vim.cmd.edit(path)
  local bufnr = vim.api.nvim_get_current_buf()
  dedalo.detach(bufnr)
  return bufnr
end

check("a buffer with no file is refused, not annotated", function()
  dedalo.setup({ cmd = FAKE })
  vim.cmd("enew")
  local bufnr = vim.api.nvim_get_current_buf()
  local seen = notifications(function()
    dedalo.attach(bufnr)
  end)
  eq(#seen, 1, "exactly one message")
  contains(seen[1].message, "no file")
  eq(marks_on(bufnr), 0, "nothing annotated")
end)

check("a file outside a git repository says so once and stops", function()
  dedalo.setup({ cmd = FAKE })
  local loose = vim.fn.tempname()
  vim.fn.mkdir(loose, "p")
  vim.fn.writefile({ "hello" }, loose .. "/f.txt")
  local bufnr = open(loose .. "/f.txt")

  local seen = notifications(function()
    dedalo.attach(bufnr)
  end)
  eq(#seen, 1, "one message, not one per redraw")
  contains(seen[1].message, "not inside a git repository")
  eq(marks_on(bufnr), 0, "nothing annotated")
end)

check("a git repository with no dedalo.toml is a hint, not a stack trace", function()
  dedalo.setup({ cmd = FAKE })
  local bufnr = open(temp_repo(false) .. "/f.txt")

  local seen = notifications(function()
    dedalo.attach(bufnr)
  end)
  eq(#seen, 1, "one message")
  contains(seen[1].message, "no dedalo.toml")
  eq(seen[1].level, vim.log.levels.WARN, "a hint, not an error")
  eq(marks_on(bufnr), 0, "nothing annotated")
end)

check("quiet mode says nothing at all, which is what auto_attach needs", function()
  dedalo.setup({ cmd = FAKE })
  local bufnr = open(temp_repo(false) .. "/f.txt")

  local seen = notifications(function()
    dedalo.attach(bufnr, { quiet = true })
  end)
  eq(#seen, 0, "auto-attach must not talk in every buffer you open")
end)

check("`dedalo` missing from PATH is reported, and reported once", function()
  dedalo.setup({ cmd = "dedalo-does-not-exist-anywhere" })
  local bufnr = open(temp_repo(true) .. "/f.txt")

  local seen = notifications(function()
    dedalo.attach(bufnr)
    vim.wait(4000, function()
      return #vim.api.nvim_buf_get_extmarks(bufnr, render.namespace, 0, -1, {}) > 0
    end, 50)
  end)
  eq(marks_on(bufnr), 0, "nothing annotated")
  eq(#seen, 1, "one message, not one per redraw")
  contains(seen[1].message, "dedalo-does-not-exist-anywhere")
end)

check("malformed JSON produces no annotation and one message", function()
  with_fake("malformed", function()
    dedalo.setup({ cmd = FAKE })
    require("dedalo.attribution").clear_cache()
    local bufnr = open(temp_repo(true) .. "/f.txt")

    local seen = notifications(function()
      dedalo.attach(bufnr)
      vim.wait(4000, function()
        return #vim.api.nvim_buf_get_extmarks(bufnr, render.namespace, 0, -1, {}) > 0
      end, 50)
    end)
    eq(marks_on(bufnr), 0, "half-written JSON must not become an annotation")
    eq(#seen, 1, "one message")
    contains(seen[1].message, "did not produce JSON")
  end)
end)

check("a failing `dedalo` is reported with what it said", function()
  with_fake("fail", function()
    dedalo.setup({ cmd = FAKE })
    require("dedalo.attribution").clear_cache()
    local bufnr = open(temp_repo(true) .. "/f.txt")

    local seen = notifications(function()
      dedalo.attach(bufnr)
      vim.wait(4000, function()
        return #vim.api.nvim_buf_get_extmarks(bufnr, render.namespace, 0, -1, {}) > 0
      end, 50)
    end)
    eq(marks_on(bufnr), 0, "nothing annotated")
    -- stderr first: a CLI that failed explains itself there, and that message
    -- is the only thing the user will see.
    contains(seen[1].message, "no dedalo.toml in this repository")
  end)
end)

check("a slow `dedalo` does not block the editor", function()
  with_fake("slow", function()
    vim.env.FAKE_DEDALO_DELAY = "2"
    dedalo.setup({ cmd = FAKE })
    require("dedalo.attribution").clear_cache()
    local bufnr = open(temp_repo(true) .. "/f.txt")

    local started = vim.uv.hrtime()
    dedalo.attach(bufnr)
    local returned_after = (vim.uv.hrtime() - started) / 1e6

    -- The call returns immediately; the subprocess is still running. If this
    -- ever blocks, users describe it as the editor hanging rather than as a
    -- plugin being slow.
    if returned_after > 500 then
      error(("attach blocked for %.0f ms"):format(returned_after))
    end

    -- And the editor is still usable while it works.
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "typed while it ran" })
    eq(vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "typed while it ran", "editable")

    dedalo.detach(bufnr)
    vim.env.FAKE_DEDALO_DELAY = nil
  end)
end)

check("the fixtures are the shape the join expects", function()
  -- The fixture is the contract. If `dedalo` renames a field, this is what
  -- says which one — rather than an end-to-end test reporting that no
  -- annotation appeared.
  local contributors =
    vim.json.decode(table.concat(vim.fn.readfile("tests/fixtures/contributors.json"), "\n"))
  local identities =
    vim.json.decode(table.concat(vim.fn.readfile("tests/fixtures/identities.json"), "\n"))

  eq(type(contributors.total_score), "number", "total_score")
  eq(type(contributors.contributions), "table", "contributions")
  eq(contributors.contributions[1].author.email, "ada@example.com", "author.email")
  eq(type(contributors.contributions[1].score), "number", "score")

  eq(identities[1].handle, "ada", "handle")
  eq(identities[1].emails[1], "ada@example.com", "emails")
  eq(identities[2].excluded, true, "excluded")
  -- An excluded identity legitimately has no wallet: that is the difference
  -- between "deliberately unpaid" and "nobody noticed".
  eq(identities[2].wallet, nil, "an excluded identity needs no wallet")
end)

check("a modified buffer keeps its uncommitted lines uncommitted", function()
  -- git blame reports work in the working tree under the all-zero sha, and
  -- the annotation must say it earns nothing yet rather than attributing it
  -- to whoever last touched the file.
  local blamed = { uncommitted = true, email = "", name = "" }
  local label, state = attribution.label(blamed, by_email)
  eq(state, "uncommitted", "state")
  contains(label, "earns nothing yet")
end)

-- --------------------------------------------------------- end to end ---

local repo = os.getenv("DEDALO_TEST_REPO")
if repo and repo ~= "" then
  dedalo.setup({ cmd = os.getenv("DEDALO_TEST_BIN") or "dedalo" })

  check("attaching a real buffer annotates it", function()
    vim.cmd.edit(repo .. "/f.txt")
    local bufnr = vim.api.nvim_get_current_buf()
    dedalo.attach(bufnr)

    local ns = require("dedalo.render").namespace
    local ready = vim.wait(30000, function()
      return #vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {}) > 0
    end, 100)
    if not ready then
      error("no annotation appeared within 30s")
    end

    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
    local text = {}
    for _, mark in ipairs(marks) do
      for _, chunk in ipairs(mark[4].virt_text or {}) do
        table.insert(text, chunk[1])
      end
    end
    local joined = table.concat(text, " ")
    io.write("        annotation: " .. joined:gsub("%s+", " ") .. "\n")

    -- Ada is linked; Bea wrote lines and has no wallet on file.
    contains(joined, "ada")
    contains(joined, "no wallet")

    dedalo.detach(bufnr)
    eq(#vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {}), 0, "detach clears")
  end)
else
  io.write("  skip  end-to-end (set DEDALO_TEST_REPO)\n")
end

-- ------------------------------------------------------------- summary ---

io.write(("\n%d passed, %d failed\n"):format(passed, #failures))
vim.cmd(("cq %d"):format(#failures == 0 and 0 or 1))
