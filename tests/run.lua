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

-- --------------------------------------------------------- end to end ---

local repo = os.getenv("DEDALO_TEST_REPO")
if repo and repo ~= "" then
  local dedalo = require("dedalo")
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
