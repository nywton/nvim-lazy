-- Harpoon replacement: a small, hand-picked, session-local list of files.
-- No persistence across restarts by design — add it later only if you find
-- you actually miss it after living with this for a while.
local M = { files = {} }

function M.add()
  local f = vim.api.nvim_buf_get_name(0)
  if f == "" then return end
  if not vim.tbl_contains(M.files, f) then
    table.insert(M.files, f)
    vim.notify("Added to quickset: " .. vim.fn.fnamemodify(f, ":."), vim.log.levels.INFO)
  end
end

function M.menu()
  if #M.files == 0 then
    vim.notify("Quickset is empty — add files with <leader>a", vim.log.levels.INFO)
    return
  end
  vim.ui.select(M.files, {
    prompt = "Quickset",
    format_item = function(f) return vim.fn.fnamemodify(f, ":.") end,
  }, function(choice)
    if choice then vim.cmd("edit " .. vim.fn.fnameescape(choice)) end
  end)
end

local function step(delta)
  if #M.files == 0 then return end
  local cur = vim.api.nvim_buf_get_name(0)
  local idx = 1
  for i, f in ipairs(M.files) do
    if f == cur then idx = i break end
  end
  idx = ((idx - 1 + delta) % #M.files) + 1
  vim.cmd("edit " .. vim.fn.fnameescape(M.files[idx]))
end

function M.next() step(1) end
function M.prev() step(-1) end

return M
