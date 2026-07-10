-- Environment plumbing that isn't really an "option" — clipboard transport,
-- filetypes core doesn't detect, PATH shims, and disabling unused remote-plugin
-- providers. Split out from options.lua so that file stays pure vim.opt/vim.g.

-- Clipboard (WSL <-> Windows, and headless Linux via OSC 52)
if vim.fn.has("wsl") == 1 then
  vim.o.clipboard = "unnamedplus"
  vim.g.clipboard = {
    name = "WslClipboard",
    copy = {
      ["+"] = "clip.exe",
      ["*"] = "clip.exe",
    },
    paste = {
      ["+"] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
      ["*"] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    },
    cache_enabled = 0,
  }
elseif vim.fn.has("linux") == 1 and not (vim.env.DISPLAY or vim.env.WAYLAND_DISPLAY) then
  -- No X/Wayland: yanks travel as OSC 52 escape codes to the LOCAL machine's
  -- clipboard instead (covers SSH, tmux passthrough, docker exec, consoles).
  vim.g.clipboard = "osc52"

  -- gx / :Open can't launch a browser here — copy the URL to the local
  -- clipboard (via OSC 52 above) instead.
  vim.ui.open = function(path)
    vim.fn.setreg("+", path)
    vim.notify("Copied to local clipboard: " .. path)
    return nil, nil
  end
  vim.ui._get_open_cmd = function()
    return { "osc52-copy-to-local-clipboard" }, nil
  end
end

-- Filetypes core doesn't detect — without this, .slim files never get a
-- filetype (FileType never fires), so legacy :syntax highlighting won't
-- activate for them.
vim.filetype.add({ extension = { slim = "slim" } })

-- No LSP, no remote-plugin hosts — disable unused providers to silence
-- optional :checkhealth warnings.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
