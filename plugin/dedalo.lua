-- Commands only. Nothing here loads the rest of the plugin: `require` happens
-- inside a command, so starting Neovim costs nothing until it is asked for.
if vim.g.loaded_dedalo then
  return
end
vim.g.loaded_dedalo = true

if vim.fn.has("nvim-0.10") == 0 then
  vim.notify("dedalo.nvim needs Neovim 0.10 or newer", vim.log.levels.ERROR)
  return
end

local function dedalo()
  return require("dedalo")
end

vim.api.nvim_create_user_command("Dedalo", function(opts)
  local action = opts.args ~= "" and opts.args or "toggle"
  local actions = {
    attach = dedalo().attach,
    detach = dedalo().detach,
    toggle = dedalo().toggle,
    refresh = dedalo().refresh,
  }
  local run = actions[action]
  if run == nil then
    vim.notify(("dedalo: unknown action `%s`"):format(action), vim.log.levels.ERROR)
    return
  end
  run()
end, {
  nargs = "?",
  desc = "Show who earns from the code in this buffer",
  complete = function(lead)
    return vim.tbl_filter(function(name)
      return name:sub(1, #lead) == lead
    end, { "attach", "detach", "toggle", "refresh" })
  end,
})
