-- Built-in statusline (vim.o.statusline), replacing lualine.nvim.
local M = {}

local branch = ""
local function refresh_branch()
  local out = vim.fn.system("git rev-parse --abbrev-ref HEAD 2>/dev/null")
  branch = vim.v.shell_error == 0 and vim.trim(out) or ""
end

vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged", "FocusGained" }, {
  callback = refresh_branch,
})

local modes = {
  n = "NORMAL", i = "INSERT", v = "VISUAL", V = "V-LINE",
  ["\22"] = "V-BLOCK", c = "COMMAND", R = "REPLACE", t = "TERMINAL",
}

function M.render()
  local mode = modes[vim.fn.mode()] or vim.fn.mode()
  local diag = vim.diagnostic.count(0)
  local errors = diag[vim.diagnostic.severity.ERROR] or 0
  local warns = diag[vim.diagnostic.severity.WARN] or 0
  local diag_str = ""
  if errors > 0 then diag_str = diag_str .. " E:" .. errors end
  if warns > 0 then diag_str = diag_str .. " W:" .. warns end

  return table.concat({
    " ", mode, " ",
    branch ~= "" and ("[" .. branch .. "] ") or "",
    "%f %m",
    diag_str,
    "%=",
    "%y ",
    os.date("%H:%M"), " ",
    "%l:%c %P ",
  })
end

vim.o.statusline = "%{%v:lua.require('ui.statusline').render()%}"

return M
