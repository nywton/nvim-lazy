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

**Fugitive** — `<leader>gg` status · `<leader>gv` side-by-side diff · `<leader>gc` commit · `<leader>gC` amend · `<leader>ga` add file · `<leader>gu` discard file · `<leader>gU` unstage file · `<leader>gb` blame · `<leader>gl` log · `<leader>gp`/`<leader>gP` pull/push · `<leader>gF` fetch · `<leader>g1`/`<leader>g2` take ours/theirs · `<leader>gr` mergetool · `<leader>gD` 3-way conflict diff

## Reviewing changes (VSCode-style side-by-side)

### 1. Open the review hub
`<leader>gg` opens the **Fugitive status** buffer — it lists every untracked / unstaged / staged file, grouped under headers. `j`/`k` move between files; `(` / `)` jump to the next/previous file across sections.

### 2. Look at a file
| Key | Action |
|-----|--------|
| `<CR>` | Open the file **maximized** (custom: opens a split and grows it to full height) |
| `o` / `gO` / `O` | Open in **horizontal split** / **vertical split** / **new tab** |
| `dv` | **Side-by-side diff** — left = index/HEAD, right = working tree (the VSCode view) |
| `dd` | Diff in a horizontal split |
| `=` | Toggle an **inline diff** right inside the status list (quick peek, no window) |
| `<` / `>` | Collapse / expand the inline diff under cursor |

### 3. Navigate the changes
| Key | Action |
|-----|--------|
| `]c` / `[c` | Next / previous changed **hunk** (works in a diff *and* in inline `=` view) |
| `<C-w>w` / `<leader><Tab>` | Switch between the two diff panes |
| `:diffupdate` | Re-sync diff highlighting after editing |

### 4. Stage / unstage / discard
From the **status buffer** (cursor on a file or a single hunk line):
| Key | Action |
|-----|--------|
| `s` | **Stage** the file or hunk under cursor (→ moves to "Staged") |
| `u` | **Unstage** the file or hunk |
| `-` | Toggle stage/unstage (handy on hunks) |
| `a` | Stage/unstage toggle on the item under cursor |
| `X` | **Discard** changes under cursor (revert file/hunk — destructive) |
| `I` | Patch-stage interactively (pick lines, like `git add -p`) |

Inside a `dv` side-by-side diff you can also merge selectively:
| Key | Action |
|-----|--------|
| `dp` | **Diff put** — push the change under cursor to the other side |
| `do` | **Diff obtain** — pull the other side's change into this file |

> Keymaps (`s`, `u`, `X`, `dv`, `=` …) work on whatever the cursor is on: a **file header** acts on the whole file, a line **inside an expanded hunk** acts on just that hunk.

### 5. Commit & finish
| Key | Action |
|-----|--------|
| `cc` | Commit staged changes (`<leader>gc` also works) |
| `ca` | Amend last commit (`<leader>gC`) |
| `g?` | Built-in help listing **every** status mapping |
| `gq` / `<C-o>` | Close the status / jump back from a diff |

**Quick loop:** `<leader>gg` → land on a file → `=` to peek (or `dv` for full side-by-side) → `]c`/`[c` through hunks → `s` to stage the good ones (`X` to discard, `u` to unstage) → `cc` to commit.

**Review against another revision:** `:Gvdiffsplit HEAD~1` · `:Gvdiffsplit main` · or `:Git difftool -y main` to load every changed file vs `main` into the quickfix-style diff list.

## Useful commands
`:Mason` install/manage LSP servers · `:LspInfo` check attached clients · `:Lazy` plugin manager · `:checkhealth` diagnose setup
