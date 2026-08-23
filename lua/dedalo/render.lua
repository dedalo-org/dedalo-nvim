--- Putting the annotation on the screen.
local M = {}

local attribution = require("dedalo.attribution")
local config = require("dedalo.config")

M.namespace = vim.api.nvim_create_namespace("dedalo")

--- Define the highlight groups, linked to whatever the colourscheme already
--- has. Linking rather than setting colours means the plugin does not fight
--- the theme, and follows it when the user changes one.
function M.setup_highlights()
  local groups = {
    DedaloLinked = { link = "Comment", default = true },
    -- The one state worth noticing: code whose author the round would skip.
    DedaloUnlinked = { link = "WarningMsg", default = true },
    DedaloUncommitted = { link = "NonText", default = true },
  }
  for name, opts in pairs(groups) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

--- Clear every annotation in `bufnr`.
---@param bufnr integer
function M.clear(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
  end
end

--- Annotate `bufnr` from a blame table and the joined attribution.
---
--- One mark per *run* of consecutive lines by the same author, not one per
--- line: a file written by one person would otherwise carry the same sentence
--- four hundred times.
---@param bufnr integer
---@param blame table
---@param by_email table
---@return integer marks
function M.apply(bufnr, blame, by_email)
  M.clear(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return 0
  end

  local total = vim.api.nvim_buf_line_count(bufnr)
  local marks = 0
  local previous = nil

  for line = 1, total do
    local blamed = blame[line]
    local key = blamed and (blamed.uncommitted and "\0uncommitted" or blamed.email) or nil

    if blamed and key ~= previous then
      local label, state = attribution.label(blamed, by_email)
      local ok = pcall(vim.api.nvim_buf_set_extmark, bufnr, M.namespace, line - 1, 0, {
        virt_text = {
          { config.current.icons[state] or "▏", config.current.highlights[state] },
          { " " .. label, config.current.highlights[state] },
        },
        virt_text_pos = config.current.virt_text_pos,
        hl_mode = "combine",
      })
      if ok then
        marks = marks + 1
      end
    end
    previous = key
  end

  return marks
end

return M
