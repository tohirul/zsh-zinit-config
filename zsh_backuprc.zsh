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
# OpenCode Workflow Root (AUTHORITATIVE)
# ------------------------------------------------------------
export OPENCODE_WORKFLOW_ROOT="$HOME/.agent/skills/vscode-opencode-workflow"
export OPENCODE_WORKFLOW_SCRIPTS="$OPENCODE_WORKFLOW_ROOT/scripts"
export PATH="$OPENCODE_WORKFLOW_SCRIPTS:$PATH"


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
# ============================================================
# Zsh Developer Framework — Ubuntu (Hardened) v2
# ============================================================

# ------------------------------------------------------------
# Powerlevel10k instant prompt (MUST be at the very top)
# ------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------
# Base environment & History
# ------------------------------------------------------------
export ZSH_HOME="$HOME/.zsh"
export PATH="$HOME/.local/bin:$PATH"

# Persistence Settings
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

# History Options (Optimized for SaaS/Distributed workflows)
setopt APPEND_HISTORY          # Append to file, don't overwrite
setopt SHARE_HISTORY           # Import/Export history across all active shells
setopt HIST_EXPIRE_DUPS_FIRST  # Trim duplicates first when reaching HISTSIZE
setopt HIST_IGNORE_DUPS        # Ignore immediate duplicates
setopt HIST_REDUCE_BLANKS      # Strip redundant whitespace
setopt HIST_VERIFY             # Let user edit history expansion before execution

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
# Zinit annexes
# ------------------------------------------------------------
zinit light-mode for \
  zdharma-continuum/zinit-annex-as-monitor \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-patch-dl

# ------------------------------------------------------------
# Core & Utility plugins (Async, Non-blocking)
# ------------------------------------------------------------
zinit wait lucid for \
  zsh-users/zsh-autosuggestions \
  zsh-users/zsh-completions \
  zsh-users/zsh-history-substring-search \
  zdharma-continuum/fast-syntax-highlighting \
  junegunn/fzf \
  ajeetdsouza/zoxide \
  changyuheng/zsh-interactive-cd \
  pick"plugins/sudo/sudo.plugin.zsh" ohmyzsh/ohmyzsh \
  pick"plugins/extract/extract.plugin.zsh" ohmyzsh/ohmyzsh \
  pick"plugins/colored-man-pages/colored-man-pages.plugin.zsh" ohmyzsh/ohmyzsh \
  pick"plugins/command-not-found/command-not-found.plugin.zsh" ohmyzsh/ohmyzsh \
  pick"plugins/copyfile/copyfile.plugin.zsh" ohmyzsh/ohmyzsh \
  pick"plugins/copypath/copypath.plugin.zsh" ohmyzsh/ohmyzsh \
  pick"plugins/web-search/web-search.plugin.zsh" ohmyzsh/ohmyzsh

# ------------------------------------------------------------
# Keybindings
# ------------------------------------------------------------
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# ------------------------------------------------------------
# Prompt
# ------------------------------------------------------------
zinit light romkatv/powerlevel10k
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# ------------------------------------------------------------
# External Tooling Integrations
# ------------------------------------------------------------
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
eval "$(zoxide init zsh)"

# Safe load for direnv to prevent initialization console output
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# ------------------------------------------------------------
# Prevent alias/function collisions
# ------------------------------------------------------------
unalias -m '*' 2>/dev/null

# ------------------------------------------------------------
# Framework libraries & Tooling
# ------------------------------------------------------------
source "$ZSH_HOME/lib/errors.zsh"
source "$ZSH_HOME/lib/utils.zsh"

source "$ZSH_HOME/tools/git.zsh"
source "$ZSH_HOME/tools/docker.zsh"
source "$ZSH_HOME/tools/node.zsh"
source "$ZSH_HOME/tools/python.zsh"
source "$ZSH_HOME/tools/system.zsh"
source "$ZSH_HOME/tools/vscode.zsh"
source "$ZSH_HOME/tools/ai.zsh"
source "$ZSH_HOME/tools/opencode.zsh"
# ------------------------------------------------------------
# User layer (Aliases & Functions last)
# ------------------------------------------------------------
source "$ZSH_HOME/aliases.zsh"
source "$ZSH_HOME/functions.zsh"

# ------------------------------------------------------------
# Add to your existing Zinit block
# ------------------------------------------------------------
zinit ice wait"0b" lucid
zinit light verlihirsh/zsh-opencode-plugin

# ------------------------------------------------------------
# Completion system (Optimized 24h cache)
# ------------------------------------------------------------
autoload -Uz compinit
if [[ -n "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"(#qN.m-1) ]]; then
  compinit -C -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
else
  compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
fi

# opencode
export PATH=/home/tohirul-islam/.opencode/bin:$PATH
export PATH="$HOME/.opencode/bin:$PATH"
