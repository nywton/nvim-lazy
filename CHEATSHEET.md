# Cheatsheet

Leader is `<Space>`. Press `<leader>t` to fuzzy-search every keymap live.

## Jump to files & locations
| Key | Action |
|-----|--------|
| `gf` | Open file under cursor (any file, incl. gitconfig paths) |
| `gF` | Open file under cursor and jump to `:line` |
| `<C-w>f` | Open file under cursor in a split |
| `gx` | Open path/URL under cursor with system handler |
| `<C-o>` / `<C-i>` | Jump back / forward (centered) |

## LSP (active only when a server is attached)
| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gr` | References |
| `gi` | Go to implementation |
| `K` | Hover docs |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>cb` / `<leader>lf` | Format buffer |
| `[d` / `]d` | Previous / next diagnostic |
| `<leader>E` | Line diagnostics float |
| `<leader>Q` | Send diagnostics to loclist |

## Find (Telescope)
| Key | Action |
|-----|--------|
| `<C-p>` | Find all files |
| `<C-f>` | Find git-tracked files |
| `<leader>s` | Live grep |
| `<leader>b` | Buffers |
| `<leader>t` | Search keymaps |
| `<leader>h` | Help tags |
| `<leader>gs` | Git status |

## Files, config & paths
| Key | Action |
|-----|--------|
| `<leader>e` | Toggle netrw in current file's dir |
| `<leader>w` / `<leader>q` | Save / quit (forced) |
| `<leader>rl` | Reload config |
| `<leader>rm` / `<leader>km` | Edit `remap.lua` |
| `<leader>vpp` | Edit `lazy.lua` |
| `<leader>cl` / `<leader>cs` | Copy absolute / relative file path |

## Editing
| Key | Action |
|-----|--------|
| `jj` | Exit insert mode |
| `;` | Enter command-line (`:`) |
| `<leader>i` | Auto-indent whole file |
| `J` / `K` (visual) | Move selection down / up |
| `<leader>p` | Paste over selection without clobbering clipboard |
| `<leader>d` | Delete without yanking |
| `<leader>r` | Replace word under cursor (interactive) |
| `<leader>y` / `<leader>Y` | Yank to system clipboard |
| `<leader>mf` | `mix format` current file (Elixir) |

## Windows, buffers & lists
| Key | Action |
|-----|--------|
| `<leader><Tab>` | Next window |
| `<C-Arrows>` | Resize splits |
| `<leader>bn` / `<leader>bv` / `<leader>bd` | Next / prev / delete buffer |
| `<C-k>` / `<C-j>` | Next / prev quickfix item |
| `<leader>k` / `<leader>j` | Next / prev loclist item |

## Harpoon
| Key | Action |
|-----|--------|
| `<leader>a` | Add file |
| `<C-e>` | Quick menu |
| `<C-h>` / `<C-t>` | Next / prev marked file |

## Git
**Gitsigns (hunks)** — `<leader>hs` stage · `<leader>hr` reset · `<leader>hS` stage buffer · `<leader>hu` undo stage · `<leader>hp` preview · `<leader>hb` blame line · `<leader>hd`/`<leader>hD` diff · `<leader>tb` toggle blame · `<leader>td` toggle deleted

**Fugitive** — `<leader>gg` status · `<leader>gc` commit · `<leader>gC` amend · `<leader>ga` add file · `<leader>gu` discard file · `<leader>gU` unstage file · `<leader>gb` blame · `<leader>gl` log · `<leader>gF` fetch · `<leader>g1`/`<leader>g2` take ours/theirs · `<leader>gr` mergetool · `<leader>gD` vertical diff

## Useful commands
`:Mason` install/manage LSP servers · `:LspInfo` check attached clients · `:Lazy` plugin manager · `:checkhealth` diagnose setup
