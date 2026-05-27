#!/bin/bash
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

link() {
  local src="$DOTFILES/$1"
  local dest="$HOME/$1"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "Backing up $dest -> $dest.bak"
    mv "$dest" "$dest.bak"
  fi
  ln -sf "$src" "$dest"
  echo "Linked $dest"
}

link .zshrc

if [[ "$(uname)" == "Darwin" ]]; then
  for dir in ~/Library/Application\ Support/JetBrains/*/; do
    cp "$DOTFILES/jetbrains/keymaps/"*.xml "$dir/keymaps/" 2>/dev/null && echo "Installed keymaps to $dir"
  done
fi
