-- Neovim's Lua runtime, not standalone Lua 5.1.
std = "luajit"
globals = { "vim" }
max_line_length = 100

exclude_files = { ".luacheckrc" }

-- Test files talk to the harness through globals it sets up.
files["tests/"] = {
  globals = { "vim", "describe", "it", "before_each", "after_each", "assert" },
}
