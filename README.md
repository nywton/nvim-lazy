# Neovim Config

---

# on arch linux:
```bash
sudo pacman -Syu
```
# tooling
```bash
sudo pacman -S base-devel gcc git cmake unzip ninja curl \
zsh git fzf fd ripgrep neovim sudo
# (Optional): Install clang too (alternative to gcc):
sudo pacman -S clang
```

## Undo Directory

This config saves undo history in:

```

\~/.local/share/nvim/undodir

````

Make sure it exists:

```bash
mkdir -p ~/.local/share/nvim/undodir
chmod 700 ~/.local/share/nvim/undodir
````

---

## Install

Clone this repo into your Neovim config folder:

```bash
git clone https://github.com/nywton/nvim-lazy ~/.config/nvim
```

Then start Neovim:

```bash
nvim
```

## Fonts

```bash
brew install --cask font-jetbrains-mono-nerd-font
```



