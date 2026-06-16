#!/bin/bash
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# -----------------------------------------------------------------------------
# Symlinks
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# JetBrains keymaps (macOS only)
# -----------------------------------------------------------------------------

if [[ "$(uname)" == "Darwin" ]]; then
  for dir in ~/Library/Application\ Support/JetBrains/*/; do
    cp "$DOTFILES/jetbrains/keymaps/"*.xml "$dir/keymaps/" 2>/dev/null && echo "Installed keymaps to $dir"
  done
fi

# -----------------------------------------------------------------------------
# Shell dependencies
# -----------------------------------------------------------------------------

# Packages required by .zshrc. Grouped by what breaks without them vs. what
# just silently degrades.
BREW_PACKAGES=(
  # sourced/eval'd directly — shell won't work properly without these
  zsh-autosuggestions
  zsh-syntax-highlighting
  zoxide
  starship
  direnv
  mise
  fzf

  # used in functions — degrades gracefully but expected to be present
  fd
  bat
  eza
  ripgrep
  htop
  ncdu
)

if [[ "$(uname)" == "Darwin" ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Install it from https://brew.sh then re-run this script."
    exit 1
  fi
  echo "Installing packages via Homebrew..."
  brew install "${BREW_PACKAGES[@]}"

elif [[ "$(uname)" == "Linux" ]]; then
  . /etc/os-release 2>/dev/null || true

  if [[ "$ID" == "ubuntu" || "$ID_LIKE" == *"debian"* || "$ID" == "debian" ]]; then
    echo ""
    echo "Ubuntu/Debian detected. Installing what's available via apt..."
    echo ""

    sudo apt update
    # Note: fd is 'fd-find' on Debian/Ubuntu; bat is 'batcat'
    sudo apt install -y \
      zsh-autosuggestions \
      zsh-syntax-highlighting \
      fzf \
      fd-find \
      bat \
      ripgrep \
      htop \
      ncdu \
      direnv

    # Alias fd-find -> fd and batcat -> bat if not already present
    mkdir -p "$HOME/.local/bin"
    if ! command -v fd >/dev/null 2>&1; then
      ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
      echo "Linked fdfind -> ~/.local/bin/fd"
    fi
    if ! command -v bat >/dev/null 2>&1; then
      ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
      echo "Linked batcat -> ~/.local/bin/bat"
    fi

    echo ""
    echo "The following tools are not in apt and need manual install:"
    echo ""
    echo "  zoxide:   curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh"
    echo "  starship: curl -sS https://starship.rs/install.sh | sh"
    echo "  mise:     curl https://mise.run | sh"
    echo "  eza:      cargo install eza   (or see https://github.com/eza-community/eza)"
    echo ""
  else
    echo ""
    echo "Unsupported Linux distribution: ${ID:-unknown}"
    echo ""
    echo "Please install the following tools manually:"
    echo ""
    for pkg in "${BREW_PACKAGES[@]}"; do
      echo "  - $pkg"
    done
    echo ""
  fi

else
  echo "Unsupported OS: $(uname)"
  exit 1
fi
