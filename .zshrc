# -----------------------------------------------------------------------------
# Local secrets
# -----------------------------------------------------------------------------

[ -f "$HOME/.zshenv.local" ] && source "$HOME/.zshenv.local"


# -----------------------------------------------------------------------------
# GCloud SDK
# -----------------------------------------------------------------------------

export CLOUDSDK_PYTHON=$(which python3)


# -----------------------------------------------------------------------------
# Homebrew
# -----------------------------------------------------------------------------

if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
elif [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Prefer GNU versions of common Unix tools
if command -v brew >/dev/null 2>&1; then
  for _brew_pkg in coreutils findutils gnu-sed grep gnu-tar; do
    _brew_prefix="$(brew --prefix "$_brew_pkg" 2>/dev/null)" || continue
    export PATH="$_brew_prefix/libexec/gnubin:$PATH"
  done

  unset _brew_pkg _brew_prefix
fi


# -----------------------------------------------------------------------------
# Editor
# -----------------------------------------------------------------------------

export EDITOR="zed --wait"
export VISUAL="zed --wait"


# -----------------------------------------------------------------------------
# Wack Mac Keys
# -----------------------------------------------------------------------------

# Home / End
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[7~' beginning-of-line
bindkey '^[[8~' end-of-line

# Delete
bindkey '^[[3~' delete-char

# Alt/Option + Left / Right: move by word
bindkey '^[[1;3D' backward-word
bindkey '^[[1;3C' forward-word

# Other common word-movement sequences
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[b' backward-word
bindkey '^[f' forward-word
bindkey '^[^[[D' backward-word
bindkey '^[^[[C' forward-word

# Edit current command in $EDITOR with CTRL+X CTRL+E
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line


# -----------------------------------------------------------------------------
# History
# -----------------------------------------------------------------------------

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt append_history
setopt share_history
setopt hist_ignore_dups
setopt hist_ignore_space
setopt inc_append_history

# Stronger history behavior
setopt extended_history
setopt hist_expire_dups_first
setopt hist_find_no_dups
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt hist_save_no_dups


# -----------------------------------------------------------------------------
# Zsh power options
# -----------------------------------------------------------------------------

setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt interactive_comments


# -----------------------------------------------------------------------------
# Better defaults
# -----------------------------------------------------------------------------

# Better ls
alias ls='eza'
alias ll='eza -la --icons --git'
alias la='eza -la --icons --git'
alias lt='eza --tree --level=2 --icons'

# Better cat, with escape hatch
alias cat='bat --paging=never'
alias ccat='command cat'

# Better top
alias top='htop'

# Disk usage
alias disk='ncdu'


# -----------------------------------------------------------------------------
# Quality-of-life aliases
# -----------------------------------------------------------------------------

alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias reload='source ~/.zshrc'
alias zshrc='zed ~/.zshrc'
alias cb='cd ~/workspace/chaturbate'
alias path='echo "$PATH" | tr ":" "\n"'
alias md='mkdir -p'


# Maintenance
alias brewup='brew update && brew upgrade && brew cleanup'
alias doctor='brew doctor'
alias ports='lsof -i -P | grep LISTEN'


# -----------------------------------------------------------------------------
# Git shortcuts
# -----------------------------------------------------------------------------

alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git lg'


# -----------------------------------------------------------------------------
# fzf
# -----------------------------------------------------------------------------

export FZF_DEFAULT_OPTS="--height=70% --layout=reverse --border --cycle --ansi --preview-window=right:60%:wrap --bind=ctrl-u:clear-query --bind=ctrl-d:half-page-down --bind=ctrl-b:half-page-up"

if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

if command -v bat >/dev/null 2>&1; then
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 -- {} 2>/dev/null'"
fi

if command -v eza >/dev/null 2>&1; then
  export FZF_ALT_C_OPTS="--preview 'eza -la --icons --git -- {} 2>/dev/null'"
fi

[ -f "$HOME/.fzf.zsh" ] && source "$HOME/.fzf.zsh"


# -----------------------------------------------------------------------------
# Fuzzy navigation / editor helpers
# -----------------------------------------------------------------------------

function _require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is not installed or not on PATH."
    return 1
  fi
}

function _fzf_files() {
  local base="${1:-.}"

  if command -v fd >/dev/null 2>&1; then
    fd --type f --hidden --follow --exclude .git . "$base"
  else
    find "$base" -type f -not -path '*/.git/*'
  fi
}

function _fzf_dirs() {
  local base="${1:-.}"

  if command -v fd >/dev/null 2>&1; then
    fd --type d --hidden --follow --exclude .git . "$base"
  else
    find "$base" -type d -not -path '*/.git/*'
  fi
}

# Fuzzy-open a file in Zed.
function fzed() {
  _require_command fzf || return 1

  local file

  file=$(
    _fzf_files "${1:-.}" |
    fzf --preview 'bat --color=always --style=numbers --line-range=:200 -- {} 2>/dev/null || cat {} 2>/dev/null'
  ) || return

  [[ -n "$file" ]] && zed "$file"
}

# Fuzzy-cd into a directory.
function fcd() {
  _require_command fzf || return 1

  local dir

  dir=$(
    _fzf_dirs "${1:-.}" |
    fzf --preview 'eza -la --icons --git -- {} 2>/dev/null || ls -la {} 2>/dev/null'
  ) || return

  [[ -n "$dir" ]] && cd "$dir"
}

# Fuzzy-cd into a workspace project.
function fproj() {
  fcd "${1:-$HOME/workspace}"
}

# Fuzzy-search file contents with ripgrep, preview matches, then open in Zed.
function frg() {
  _require_command fzf || return 1
  _require_command rg || return 1

  local query selected file rest line col

  if (( $# == 0 )); then
    read "query?Search text: "
  else
    query="$*"
  fi

  [[ -z "$query" ]] && return 1

  selected=$(
    rg --hidden --glob '!.git' --line-number --column --no-heading --smart-case "$query" |
    fzf \
      --delimiter ':' \
      --preview 'bat --color=always --style=numbers --highlight-line {2} -- {1} 2>/dev/null' \
      --preview-window 'right:60%:+{2}/2'
  ) || return

  file="${selected%%:*}"
  rest="${selected#*:}"
  line="${rest%%:*}"
  rest="${rest#*:}"
  col="${rest%%:*}"

  [[ -n "$file" && -n "$line" ]] && zed "$file:$line:$col"
}

# Fuzzy-search shell history and put the selected command on your prompt.
# It does not auto-run the command.
function fhist() {
  _require_command fzf || return 1

  local cmd

  cmd=$(
    fc -rl 1 |
    fzf |
    sed 's/^[[:space:]]*[0-9]*[[:space:]]*//'
  ) || return

  [[ -n "$cmd" ]] && print -z "$cmd"
}

alias ff='fzed'
alias fdv='fcd'
alias fp='fproj'
alias srch='frg'
alias hf='fhist'


# -----------------------------------------------------------------------------
# direnv
# -----------------------------------------------------------------------------

eval "$(direnv hook zsh)"


# -----------------------------------------------------------------------------
# mise
# -----------------------------------------------------------------------------

eval "$(mise activate zsh)"


# -----------------------------------------------------------------------------
# Corepack
# -----------------------------------------------------------------------------

export COREPACK_ENABLE_AUTO_PIN=1


# -----------------------------------------------------------------------------
# Google Cloud SDK
# -----------------------------------------------------------------------------

# Force gcloud to use the desired Python runtime when needed.
# Update this path if your Python version changes.
export CLOUDSDK_PYTHON="/Library/Frameworks/Python.framework/Versions/3.12/bin/python3"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/opt/google-cloud-sdk/path.zsh.inc' ]; then . '/opt/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/opt/google-cloud-sdk/completion.zsh.inc' ]; then . '/opt/google-cloud-sdk/completion.zsh.inc'; fi


# -----------------------------------------------------------------------------
# CB-specific
# -----------------------------------------------------------------------------

CB="$HOME/workspace/chaturbate"
[ -f "$CB/.bin/lib/common.sh" ] && source "$CB/.bin/lib/common.sh"
export DOCKER_FOLDER="$CB"
export DS_PROJECT_NAME="$(basename "$DOCKER_FOLDER")"
# export cb dc dcr  # may need to omit in zsh
export PATH="$DOCKER_FOLDER/.bin:$PATH"


# -----------------------------------------------------------------------------
# Local user bin
# -----------------------------------------------------------------------------

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"


# -----------------------------------------------------------------------------
# Network helpers
# -----------------------------------------------------------------------------

function local-ip() {
  local ip iface

  ip="$(ipconfig getifaddr en0 2>/dev/null)"

  if [[ -z "$ip" ]]; then
    ip="$(ipconfig getifaddr en1 2>/dev/null)"
  fi

  if [[ -z "$ip" ]]; then
    iface="$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}')"

    if [[ -n "$iface" ]]; then
      ip="$(ipconfig getifaddr "$iface" 2>/dev/null)"
    fi
  fi

  echo "$ip"
}

function myip() {
  local ip

  ip="$(local-ip)"

  if [[ -z "$ip" ]]; then
    echo "Network IP not found."
    return 1
  fi

  echo "Network IP: $ip"
}


# -----------------------------------------------------------------------------
# Docker / Compose shortcuts
# -----------------------------------------------------------------------------

alias pyshell='docker compose run --rm manage shell'
alias dcudb='docker compose up -d --build'

# Fuzzy shell into a running container.
function dsh() {
  _require_command fzf || return 1
  _require_command docker || return 1

  local container

  container=$(
    docker ps --format '{{.Names}}' |
    fzf --header='Select running container'
  ) || return

  [[ -n "$container" ]] || return 1

  docker exec -it "$container" sh -lc 'if command -v bash >/dev/null 2>&1; then exec bash; else exec sh; fi'
}

# Fuzzy-follow logs for any container.
function dlogs() {
  _require_command fzf || return 1
  _require_command docker || return 1

  local container

  container=$(
    docker ps -a --format '{{.Names}}' |
    fzf \
      --header='Select container for logs' \
      --preview 'docker logs --tail=80 {} 2>&1'
  ) || return

  [[ -n "$container" ]] && docker logs -f --tail=200 "$container"
}

# Fuzzy-stop one or more running containers.
function dstop() {
  _require_command fzf || return 1
  _require_command docker || return 1

  local containers confirm

  containers=("${(@f)$(docker ps --format '{{.Names}}' | fzf -m --header='TAB select containers to stop')}")

  if (( ${#containers[@]} == 0 )); then
    return 0
  fi

  echo "Stop containers?"
  printf '  %s\n' "${containers[@]}"
  echo

  read "confirm?Continue? [y/N] "

  if [[ "$confirm" == [Yy] ]]; then
    docker stop "${containers[@]}"
  else
    echo "No containers stopped."
  fi
}


# -----------------------------------------------------------------------------
# Git helpers
# -----------------------------------------------------------------------------

function _is-git-repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

function git-get-remote-branch() {
  if [ -z "$1" ]; then
    echo "Usage: git-get-remote-branch <branch_name>"
    return 1
  fi

  local branch="$1"

  git fetch origin || return $?
  git checkout -b "$branch" "origin/$branch"
}


function git-latest-branches() {
  echo "glb is deprecated — use fbr instead."
  fbr
}

# Fetch master and fast-forward merge it into the current branch.
function git-pull-merge-master() {
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)

  if [[ "$current_branch" == "master" ]]; then
    echo "You are already on 'master'. Aborting merge."
    return 1
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "You have uncommitted changes. Commit or stash before merging."
    return 1
  fi

  git fetch origin master:master || return $?
  git merge --ff-only master
}

alias grb='git-get-remote-branch'
alias gpmm='git-pull-merge-master'
alias glb='git-latest-branches'


# -----------------------------------------------------------------------------
# Fuzzy Git helpers
# -----------------------------------------------------------------------------

# Fuzzy checkout local branch.
function fbr() {
  _require_command fzf || return 1

  _is-git-repo || {
    echo "Not inside a git repo."
    return 1
  }

  local branch

  branch=$(
    git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads |
    fzf --preview 'git log --oneline --decorate --graph --color=always -30 {}'
  ) || return

  [[ -n "$branch" ]] && git checkout "$branch"
}

# Fuzzy checkout remote origin branch.
function fbrm() {
  _require_command fzf || return 1

  _is-git-repo || {
    echo "Not inside a git repo."
    return 1
  }

  git fetch --all --prune || return $?

  local branch

  branch=$(
    git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/remotes/origin |
    sed 's#^origin/##' |
    grep -v '^HEAD$' |
    fzf --preview 'git log --oneline --decorate --graph --color=always -30 origin/{}'
  ) || return

  [[ -z "$branch" ]] && return 1

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git checkout "$branch"
  else
    git checkout -b "$branch" "origin/$branch"
  fi
}

# Fuzzy-select a commit and show it.
function fshow() {
  _require_command fzf || return 1

  _is-git-repo || {
    echo "Not inside a git repo."
    return 1
  }

  local commit

  commit=$(
    git log --date=relative --pretty=format:'%h %cr %an %s%d' |
    fzf --no-sort --preview 'git show --color=always --stat --patch {1}' |
    awk '{print $1}'
  ) || return

  [[ -n "$commit" ]] && git show --color=always "$commit"
}

# Fuzzy-open changed/untracked files in Zed.
function fchanged() {
  _require_command fzf || return 1

  _is-git-repo || {
    echo "Not inside a git repo."
    return 1
  }

  local file

  file=$(
    {
      git diff --name-only
      git diff --name-only --cached
      git ls-files --others --exclude-standard
    } |
    sort -u |
    fzf --preview 'git diff --color=always -- {}; git diff --cached --color=always -- {}; bat --color=always --style=numbers --line-range=:200 -- {} 2>/dev/null'
  ) || return

  [[ -n "$file" ]] && zed "$file"
}

# Fuzzy-select a tag and show it.
function ftag() {
  _require_command fzf || return 1

  _is-git-repo || {
    echo "Not inside a git repo."
    return 1
  }

  local tag

  tag=$(
    git tag --sort=-creatordate |
    fzf --preview 'git show --color=always --stat {}'
  ) || return

  [[ -n "$tag" ]] && git show --color=always "$tag"
}

# Fuzzy-inspect stashes.
function fstash() {
  _require_command fzf || return 1

  _is-git-repo || {
    echo "Not inside a git repo."
    return 1
  }

  local stash

  stash=$(
    git stash list --format='%gd %cr %gs' |
    fzf --preview 'git stash show -p --color=always {1}'
  ) || return

  [[ -n "$stash" ]] && git stash show -p --color=always "${stash%% *}"
}

alias gfb='fbr'
alias gfr='fbrm'
alias gfc='fshow'
alias gfw='fchanged'
alias gfs='fstash'
alias gft='ftag'


# -----------------------------------------------------------------------------
# Formatting helpers
# -----------------------------------------------------------------------------

alias format-branch='cd "$(git rev-parse --show-toplevel)" && { git diff --name-only master...HEAD; git diff --name-only HEAD; } | sort -u | xargs npx prettier --write --ignore-unknown'


# -----------------------------------------------------------------------------
# Process / port helpers
# -----------------------------------------------------------------------------

# Fuzzy-kill a process with confirmation.
function fkill() {
  _require_command fzf || return 1

  local line pid confirm

  line=$(
    ps -axo pid,user,comm,args |
    sed 1d |
    fzf --header='Select process to kill'
  ) || return

  pid=$(awk '{print $1}' <<< "$line")

  [[ -z "$pid" ]] && return 1

  echo "$line"
  echo

  read "confirm?Kill PID $pid? [y/N] "

  if [[ "$confirm" == [Yy] ]]; then
    kill "$pid"
  else
    echo "No process killed."
  fi
}

# Fuzzy-kill a process listening on a port with confirmation.
function fkillport() {
  _require_command fzf || return 1

  local line pid confirm

  line=$(
    lsof -nP -iTCP -sTCP:LISTEN |
    sed 1d |
    fzf --header='Select listening port process to kill'
  ) || return

  pid=$(awk '{print $2}' <<< "$line")

  [[ -z "$pid" ]] && return 1

  echo "$line"
  echo

  read "confirm?Kill PID $pid? [y/N] "

  if [[ "$confirm" == [Yy] ]]; then
    kill "$pid"
  else
    echo "No process killed."
  fi
}

alias fk='fkill'
alias fkp='fkillport'


# -----------------------------------------------------------------------------
# LocalTunnel / LambdaTest tunnel
# -----------------------------------------------------------------------------

# Set this in a private file, password manager, or shell session:
# export LT_USER="user@email.com"
# export LT_ACCESS_KEY="your-key-here"
#
# Do not hard-code the key directly in .zshrc.

function lt-tunnel-connect() {
  if [[ -z "$LT_ACCESS_KEY" ]]; then
    echo "LT_ACCESS_KEY is not set."
    return 1
  fi

  if [[ -z "$LT_USER" ]]; then
    echo "LT_USER is not set."
    return 1
  fi

  if [[ ! -x "$HOME/Downloads/LT" ]]; then
    echo "LambdaTest binary not found or not executable: $HOME/Downloads/LT"
    return 1
  fi

  myip
  "$HOME/Downloads/LT" --user "$LT_USER" --key "$LT_ACCESS_KEY"
}

alias lt-tunnel='lt-tunnel-connect'


# -----------------------------------------------------------------------------
# Starship prompt
# Keep this near the bottom.
# -----------------------------------------------------------------------------

eval "$(starship init zsh)"

# -----------------------------------------------------------------------------
# Shell help
# -----------------------------------------------------------------------------

function help() {
  emulate -L zsh

  local BOLD=$'\033[1m'
  local DIM=$'\033[2m'
  local RESET=$'\033[0m'
  local CYAN=$'\033[36m'
  local GREEN=$'\033[32m'
  local YELLOW=$'\033[33m'
  local MAGENTA=$'\033[35m'

  local LINE="${DIM}────────────────────────────────────────────────────────────${RESET}"

  print
  print -r -- "${BOLD}${MAGENTA}Custom shell help${RESET}"
  print -r -- "${DIM}Your aliases, functions, and fzf-powered workflows from ~/.zshrc.${RESET}"
  print

  print -r -- "${BOLD}${CYAN}Navigation / files${RESET}"
  print -r -- "$LINE"
  printf "  ${GREEN}%-24s${RESET} %s\n" ".." "cd up one directory"
  printf "  ${GREEN}%-24s${RESET} %s\n" "..." "cd up two directories"
  printf "  ${GREEN}%-24s${RESET} %s\n" "cb" "cd to ~/workspace/chaturbate"
  printf "  ${GREEN}%-24s${RESET} %s\n" "fcd / fdv" "fuzzy-cd into a directory"
  printf "  ${GREEN}%-24s${RESET} %s\n" "fproj / fp" "fuzzy-cd into ~/workspace, or a supplied base path"
  printf "  ${GREEN}%-24s${RESET} %s\n" "path" "print PATH one entry per line"
  printf "  ${GREEN}%-24s${RESET} %s\n" "md" "mkdir -p"
  printf "  ${GREEN}%-24s${RESET} %s\n" "z <query>" "jump to a frecent directory (zoxide)"
  printf "  ${GREEN}%-24s${RESET} %s\n" "zi" "fuzzy-pick a frecent directory (zoxide + fzf)"

  print
  print -r -- "${BOLD}${CYAN}File viewing / search${RESET}"
  print -r -- "$LINE"
  printf "  ${GREEN}%-24s${RESET} %s\n" "ls" "eza"
  printf "  ${GREEN}%-24s${RESET} %s\n" "ll / la" "detailed eza listing with icons and git status"
  printf "  ${GREEN}%-24s${RESET} %s\n" "lt" "tree view, 2 levels deep"
  printf "  ${GREEN}%-24s${RESET} %s\n" "cat" "bat with paging disabled"
  printf "  ${GREEN}%-24s${RESET} %s\n" "ccat" "real system cat"
  printf "  ${GREEN}%-24s${RESET} %s\n" "fzed / ff" "fuzzy-open a file in Zed with preview"
  printf "  ${GREEN}%-24s${RESET} %s\n" "frg / srch" "ripgrep search, preview matches, open result in Zed"
  printf "  ${GREEN}%-24s${RESET} %s\n" "grep" "grep with color"

  print
  print -r -- "${BOLD}${CYAN}fzf keys${RESET}"
  print -r -- "$LINE"
  printf "  ${YELLOW}%-24s${RESET} %s\n" "CTRL+R" "fuzzy-search command history"
  printf "  ${YELLOW}%-24s${RESET} %s\n" "CTRL+T" "fuzzy-select a file and insert it into the command line"
  printf "  ${YELLOW}%-24s${RESET} %s\n" "ALT+C" "fuzzy-cd into a directory"
  printf "  ${GREEN}%-24s${RESET} %s\n" "fhist / hf" "fuzzy-pick history and place command on prompt without running it"

  print
  print -r -- "${BOLD}${CYAN}Git basics${RESET}"
  print -r -- "$LINE"
  printf "  ${GREEN}%-24s${RESET} %s\n" "gs" "git status"
  printf "  ${GREEN}%-24s${RESET} %s\n" "ga" "git add"
  printf "  ${GREEN}%-24s${RESET} %s\n" "gc" "git commit"
  printf "  ${GREEN}%-24s${RESET} %s\n" "gp" "git push"
  printf "  ${GREEN}%-24s${RESET} %s\n" "gl" "git lg"
  printf "  ${GREEN}%-24s${RESET} %s\n" "grb" "create local branch from origin/<branch>"
  printf "  ${GREEN}%-24s${RESET} %s\n" "gpmm" "fetch master and fast-forward merge it into current branch"
  printf "  ${GREEN}%-24s${RESET} %s\n" "glb" "(deprecated) use fbr instead"
  printf "  ${GREEN}%-24s${RESET} %s\n" "format-branch" "prettier-format files changed on current branch"

  print
  print -r -- "${BOLD}${CYAN}Fuzzy Git${RESET}"
  print -r -- "$LINE"
  printf "  ${GREEN}%-24s${RESET} %s\n" "gfb / fbr" "fuzzy-checkout local branch"
  printf "  ${GREEN}%-24s${RESET} %s\n" "gfr / fbrm" "fetch/prune, then fuzzy-checkout remote branch"
  printf "  ${GREEN}%-24s${RESET} %s\n" "gfc / fshow" "fuzzy-select a commit and show it"
  printf "  ${GREEN}%-24s${RESET} %s\n" "gfw / fchanged" "fuzzy-open changed, staged, or untracked files in Zed"
  printf "  ${GREEN}%-24s${RESET} %s\n" "gfs / fstash" "fuzzy-inspect git stashes"
  printf "  ${GREEN}%-24s${RESET} %s\n" "gft / ftag" "fuzzy-select a tag and show it"

  print
  print -r -- "${BOLD}${CYAN}Docker / Compose${RESET}"
  print -r -- "$LINE"
  printf "  ${GREEN}%-24s${RESET} %s\n" "pyshell" "docker compose run --rm manage shell"
  printf "  ${GREEN}%-24s${RESET} %s\n" "dcudb" "docker compose up -d --build"
  printf "  ${GREEN}%-24s${RESET} %s\n" "dsh" "fuzzy-shell into a running container"
  printf "  ${GREEN}%-24s${RESET} %s\n" "dlogs" "fuzzy-follow logs for a container"
  printf "  ${GREEN}%-24s${RESET} %s\n" "dstop" "fuzzy-stop selected running containers"

  print
  print -r -- "${BOLD}${CYAN}Processes / ports${RESET}"
  print -r -- "$LINE"
  printf "  ${GREEN}%-24s${RESET} %s\n" "ports" "list listening ports"
  printf "  ${GREEN}%-24s${RESET} %s\n" "fkill / fk" "fuzzy-kill a process with confirmation"
  printf "  ${GREEN}%-24s${RESET} %s\n" "fkillport / fkp" "fuzzy-kill a process listening on a port"

  print
  print -r -- "${BOLD}${CYAN}Network / tunnels${RESET}"
  print -r -- "$LINE"
  printf "  ${GREEN}%-24s${RESET} %s\n" "local-ip" "print local network IP only"
  printf "  ${GREEN}%-24s${RESET} %s\n" "myip" "print labeled local network IP"
  printf "  ${GREEN}%-24s${RESET} %s\n" "lt-tunnel" "start LambdaTest tunnel using LT_USER and LT_ACCESS_KEY"

  print
  print -r -- "${BOLD}${CYAN}Maintenance / config${RESET}"
  print -r -- "$LINE"
  printf "  ${GREEN}%-24s${RESET} %s\n" "reload" "source ~/.zshrc"
  printf "  ${GREEN}%-24s${RESET} %s\n" "zshrc" "open ~/.zshrc in Zed"
  printf "  ${GREEN}%-24s${RESET} %s\n" "brewup" "brew update, upgrade, and cleanup"
  printf "  ${GREEN}%-24s${RESET} %s\n" "doctor" "brew doctor"
  printf "  ${GREEN}%-24s${RESET} %s\n" "disk" "ncdu disk usage browser"
  printf "  ${GREEN}%-24s${RESET} %s\n" "top" "htop"

  print
}
# -----------------------------------------------------------------------------
# zsh-autosuggestions
# -----------------------------------------------------------------------------

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh


# -----------------------------------------------------------------------------
# zoxide  (z / zi)
# -----------------------------------------------------------------------------

eval "$(zoxide init zsh)"

alias cd='z'


# -----------------------------------------------------------------------------
# zsh-syntax-highlighting
# Must be sourced last.
# -----------------------------------------------------------------------------

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh


# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/mpowers/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
