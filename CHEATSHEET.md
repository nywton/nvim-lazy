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

## Movement & search (auto-centered)
Plain motions are remapped to keep the cursor vertically centered (`zz`) 
so you never lose context scrolling — same muscle memory, just less hunting for where the cursor 
landed.
| Key | Action |
|-----|--------|
| `j` / `k` | Move down / up a line, centered |
| `<C-d>` / `<C-u>` | Half-page down / up, centered |
| `n` / `N` | Next / previous search match, centered |
| `*` / `#` | Search word under cursor forward / backward, centered |
| `G` | Go to end of file, centered |

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
| `<leader>lsp` | Toggle LSP on/off (saves resources) |

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
| `<leader>v` | Visual block mode (alt for `<C-v>`) |
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

## Terminal (quick switcher)
Toggles a reusable terminal — hiding it **keeps the session running** in the background (run `claude`, hide it, keep coding, toggle back and it's still going). Float and split are separate sessions.
| Key | Action |
|-----|--------|
| `<leader>tt` | Toggle floating terminal |
| `<leader>ts` | Toggle bottom split terminal |
| `<Esc><Esc>` | Leave terminal-insert → normal mode |

> Hide with the same toggle key — don't `:q`/`:bd` the buffer, that kills the running process.

## Harpoon
| Key | Action |
|-----|--------|
| `<leader>a` | Add file |
| `<C-e>` | Quick menu |
| `<C-h>` / `<C-t>` | Next / prev marked file |

## Git
**Gitsigns (hunks)** — `]c`/`[c` next/prev changed hunk · `<leader>hs` stage · `<leader>hr` reset · `<leader>hS` stage buffer · `<leader>hu` undo stage · `<leader>hp` preview · `<leader>hb` blame line · `<leader>hd`/`<leader>hD` diff · `<leader>tb` toggle blame · `<leader>td` toggle deleted

**Fugitive** — `<leader>gg` status · `<leader>gv` side-by-side diff · `<leader>g-` diff vs HEAD~1 · `<leader>gM` diff vs origin/main · `<leader>gi` incoming commits · `<leader>gd` difftool all files vs upstream · `<leader>gc` commit · `<leader>gC` amend · `<leader>ga` add file · `<leader>gu` discard file · `<leader>gU` unstage file · `<leader>gb` blame · `<leader>gl` log · `<leader>gp`/`<leader>gP` pull/push · `<leader>gF` fetch · `<leader>g1`/`<leader>g2` take ours/theirs · `<leader>gr` mergetool · `<leader>gD` 3-way conflict diff

**Diffview** — `<leader>gh` file history (current file) · `<leader>gH` repo-wide history

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

## Reviewing committed changes (office repo / PR review)

### 🌅 Morning review — what changed in the last pull

Two modes depending on how you want to browse:

| Key | Mode | Best for |
|-----|------|----------|
| `<leader>go` | **File-panel view** — all changed files listed on the left, diff on the right | Quickly scanning which files changed and jumping between hunks |
| `<leader>gO` | **Commit-list view** — each commit listed, Tab walks commit by commit | Understanding *what each commit did*, reading history |

#### `<leader>go` — file-panel (all changes at once)
After `git pull`, opens `DiffviewOpen ORIG_HEAD` (falls back to upstream if no ORIG_HEAD):
| Key | Action |
|-----|--------|
| `<Tab>` / `<S-Tab>` | **Next / prev changed file** (loads its diff instantly) |
| `j` / `k` | Move cursor in file list only |
| `]c` / `[c` | Next / prev **hunk** within the current file diff |
| `<C-f>` / `<C-b>` | Scroll diff down / up |
| `q` / `:DiffviewClose` | Close |

#### `<leader>gO` — commit-list (commit by commit)
Opens `DiffviewFileHistory --range=ORIG_HEAD..HEAD` — commit log + diff panel:
| Key | Action |
|-----|--------|
| `<Tab>` / `<S-Tab>` | **Next / prev commit** — loads that commit's diff |
| `j` / `k` | Move cursor in commit list only (no diff update) |
| `<C-A-d>` | **Drill into commit** → opens it in DiffviewOpen with full file list |
| `L` | Show full commit message |
| `<C-f>` / `<C-b>` | Scroll diff |
| `q` / `:DiffviewClose` | Close |

Once inside a commit via `<C-A-d>` (DiffviewOpen):
| Key | Action |
|-----|--------|
| `<Tab>` / `<S-Tab>` | **Next / prev file** changed in that commit |
| `]c` / `[c` | Next / prev **hunk** within the file |
| `<C-f>` / `<C-b>` | Scroll diff |
| `q` | Close and return |

> **Full drill-down:** `<leader>gO` → `<Tab>` through commits → `<C-A-d>` to expand a commit → `<Tab>` through its files → `]c`/`[c` through hunks.

> **Morning loop:** `<leader>gp` (pull) → `<leader>gO` for commit-by-commit overview → `<leader>go` to deep-dive into specific files with hunk navigation.

### Workflow: see what's new in the remote (before pulling)
| Step | Key | Action |
|------|-----|--------|
| 1 | `<leader>gF` | Fetch remote (update `origin/*` refs) |
| 2 | `<leader>gi` | Show commits in upstream not yet in HEAD — opens a log buffer |
| 3 | `<CR>` on any commit | Open that commit's full diff (Fugitive object view) |
| 4 | `]c` / `[c` | Jump between hunks inside the commit diff |
| 5 | `<C-o>` | Return to the log buffer |

### Workflow: systematic file-by-file review vs upstream
| Step | Key | Action |
|------|-----|--------|
| 1 | `<leader>gF` | Fetch |
| 2 | `<leader>gd` | Load **all** files changed vs upstream into quickfix |
| 3 | `<C-k>` / `<C-j>` | Walk file-by-file through the diff list |

### File history (Diffview)
`<leader>gh` opens **DiffviewFileHistory** for the current file — commit log panel + diff panel.

| Key | Action |
|-----|--------|
| `<leader>gh` | File history — current file |
| `<leader>gH` | Repo-wide commit history |
| `<Tab>` / `<S-Tab>` | **Next / prev commit — moves cursor AND loads diff** (best for quick review) |
| `j` / `k` | Move cursor in log panel only (does NOT update diff) |
| `<CR>` | Open diff for commit under cursor |
| `L` | Show full commit message/details |
| `gf` | Open file at that revision in editor |
| `y` | Copy commit hash |
| `<C-f>` / `<C-b>` | Scroll the diff panel down / up |
| `q` / `:DiffviewClose` | Close diffview |

> **Quick review loop:** `<leader>gh` → mash `<Tab>` to walk commits forward, `<S-Tab>` to go back — the diff loads automatically on each step. Use `<C-f>`/`<C-b>` to scroll a large diff without leaving the log.

### Quick comparisons
| Key | Action |
|-----|--------|
| `<leader>gv` | Diff current file vs index/HEAD (working-tree review) |
| `<leader>g-` | Diff current file vs **previous commit** (HEAD~1) |
| `<leader>gM` | Diff current file vs **upstream** (origin/main) |
| `]c` / `[c` | Jump hunks in any open diff |
| `<C-w>w` / `<leader><Tab>` | Switch between the two diff panes |

> `<leader>gi` and `<leader>gM` and `<leader>gd` auto-detect your branch's upstream (`@{u}`), falling back to `origin/main`.

## Useful commands
`:LspInfo` check attached clients · `:Lazy` plugin manager · `:checkhealth` diagnose setup
