-- Built-in 'autocomplete' option (nvim 0.12). The popup opens as you type;
-- sources come from 'complete' (Vim default: buffer/window/included/tag
-- words — no LSP, no completion plugin).

vim.o.autocomplete = true
vim.o.completeopt = "menuone,noselect,popup,fuzzy"
vim.opt.shortmess:append("c") -- no "match x of y" messages while completing

local t = function(keys)
  return vim.api.nvim_replace_termcodes(keys, true, true, true)
end

vim.keymap.set("i", "<Tab>", function()
  return vim.fn.pumvisible() == 1 and t("<C-n>") or t("<Tab>")
end, { expr = true, replace_keycodes = false, silent = true })

vim.keymap.set("i", "<S-Tab>", function()
  return vim.fn.pumvisible() == 1 and t("<C-p>") or t("<S-Tab>")
end, { expr = true, replace_keycodes = false, silent = true })

-- <CR> accepts the selected completion item; otherwise a plain <CR>.
-- (No nvim-autopairs here, so no pairing fallback needed.)
vim.keymap.set("i", "<CR>", function()
  if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected >= 0 then
    return t("<C-y>")
  end
  return t("<CR>")
end, { expr = true, replace_keycodes = false, silent = true })
