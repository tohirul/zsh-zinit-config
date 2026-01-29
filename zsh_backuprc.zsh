# ============================================================
# Zsh Developer Framework — Ubuntu (Hardened)
# ============================================================

# ------------------------------------------------------------
# Powerlevel10k instant prompt (MUST be at the very top)
# ------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------
# Base environment
# ------------------------------------------------------------
export ZSH_HOME="$HOME/.zsh"
export PATH="$HOME/.local/bin:$PATH"

# ------------------------------------------------------------
# Zinit (plugin manager)
# ------------------------------------------------------------
if [[ ! -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ]]; then
  mkdir -p "$HOME/.local/share/zinit"
  git clone https://github.com/zdharma-continuum/zinit.git \
    "$HOME/.local/share/zinit/zinit.git"
fi
source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"

# ------------------------------------------------------------
# Zinit annexes (required, no turbo)
# ------------------------------------------------------------
zinit light-mode for \
  zdharma-continuum/zinit-annex-as-monitor \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-patch-dl

# ------------------------------------------------------------
# Core plugins (async, non-blocking)
# ------------------------------------------------------------
zinit wait lucid for \
  zsh-users/zsh-autosuggestions \
  zsh-users/zsh-completions \
  zsh-users/zsh-history-substring-search \
  zdharma-continuum/fast-syntax-highlighting \
  junegunn/fzf \
  ajeetdsouza/zoxide \
  changyuheng/zsh-interactive-cd

# ------------------------------------------------------------
# Utility plugins (OMZ, correctly loaded via zinit)
# ------------------------------------------------------------
zinit wait"0a" lucid for \
  pick"plugins/sudo/sudo.plugin.zsh" ohmyzsh/ohmyzsh \
  pick"plugins/extract/extract.plugin.zsh" ohmyzsh/ohmyzsh \
  pick"plugins/colored-man-pages/colored-man-pages.plugin.zsh" ohmyzsh/ohmyzsh \
  pick"plugins/command-not-found/command-not-found.plugin.zsh" ohmyzsh/ohmyzsh

# ------------------------------------------------------------
# Keybindings (AFTER plugins define widgets)
# ------------------------------------------------------------
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# ------------------------------------------------------------
# Prompt
# ------------------------------------------------------------
zinit light romkatv/powerlevel10k
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# ------------------------------------------------------------
# fzf shell keybindings (Ctrl-R, Ctrl-T, Alt-C)
# ------------------------------------------------------------
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# ------------------------------------------------------------
# zoxide (directory jumping)
# ------------------------------------------------------------
eval "$(zoxide init zsh)"

# ------------------------------------------------------------
# Prevent alias/function collisions (CRITICAL)
# Must run AFTER plugins, BEFORE framework functions
# ------------------------------------------------------------
unalias -m '*' 2>/dev/null

# ------------------------------------------------------------
# Framework libraries
# ------------------------------------------------------------
source "$ZSH_HOME/lib/errors.zsh"
source "$ZSH_HOME/lib/utils.zsh"

# ------------------------------------------------------------
# Tooling layers (functions only)
# ------------------------------------------------------------
source "$ZSH_HOME/tools/git.zsh"
source "$ZSH_HOME/tools/docker.zsh"
source "$ZSH_HOME/tools/node.zsh"
source "$ZSH_HOME/tools/python.zsh"
source "$ZSH_HOME/tools/system.zsh"
source "$ZSH_HOME/tools/vscode.zsh"

# ------------------------------------------------------------
# User layer (aliases last)
# ------------------------------------------------------------
source "$ZSH_HOME/aliases.zsh"
source "$ZSH_HOME/functions.zsh"

# ------------------------------------------------------------
# Completion system (cached, hardened)
# Optimized compinit with 24h cache check
# ------------------------------------------------------------
autoload -Uz compinit
if [[ -n ${XDG_CACHE_HOME/zsh/zcompdump}(#qN.m-1) ]]; then
  compinit -C -d "$XDG_CACHE_HOME/zsh/zcompdump"
else
  compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
fi
