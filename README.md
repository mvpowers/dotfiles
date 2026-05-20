# dotfiles

My personal shell config.

## Setup

```bash
git clone git@github.com:mvpowers/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

`install.sh` symlinks each dotfile into `~`. If a file already exists it gets backed up as `<file>.bak` before being replaced.

## Contents

| File | Purpose |
|------|---------|
| `.zshrc` | Zsh configuration |
