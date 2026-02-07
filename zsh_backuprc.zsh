# ============================================================
# Zsh Developer Framework — Ubuntu (Hardened, Authoritative)
# ============================================================

# ------------------------------------------------------------
# Powerlevel10k instant prompt (MUST be first)
# ------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------
# Base Environment
# ------------------------------------------------------------
export ZSH_HOME="$HOME/.zsh"
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"

# ------------------------------------------------------------
# OpenCode Workflow Root (AUTHORITATIVE)
# ------------------------------------------------------------
# NOTE:
# - Scripts are NOT added to PATH
# - Access ONLY via oc_* adapters
# ------------------------------------------------------------
export OPENCODE_WORKFLOW_ROOT="$HOME/.agent/skills/vscode-opencode-workflow"
export OPENCODE_WORKFLOW_SCRIPTS="$OPENCODE_WORKFLOW_ROOT/scripts"

# ------------------------------------------------------------
# History (Hardened, Shared)
# ------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# ------------------------------------------------------------
# Zinit (Plugin Manager)
# ------------------------------------------------------------
if [[ ! -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ]]; then
  mkdir -p "$HOME/.local/share/zinit"
  git clone https://github.com/zdharma-continuum/zinit.git \
    "$HOME/.local/share/zinit/zinit.git"
fi
source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"

# ------------------------------------------------------------
# Zinit Annexes (Required)
# ------------------------------------------------------------
zinit light-mode for \
  zdharma-continuum/zinit-annex-as-monitor \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-patch-dl

# ------------------------------------------------------------
# Core Plugins (Async, Non-blocking)
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
# Utility Plugins (Oh-My-Zsh via Zinit)
# ------------------------------------------------------------
zinit wait"0a" lucid for \
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

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# ------------------------------------------------------------
# Prevent Alias / Function Collisions (CRITICAL)
# ------------------------------------------------------------

# ------------------------------------------------------------
# Framework Libraries
# ------------------------------------------------------------
source "$ZSH_HOME/lib/errors.zsh"
source "$ZSH_HOME/lib/utils.zsh"

# ------------------------------------------------------------
# Tooling Layers (THIN ADAPTERS ONLY)
# ------------------------------------------------------------
# NOTE:
# - NO orchestration logic here
# - NO model selection
# - NO context mutation
# ------------------------------------------------------------
source "$ZSH_HOME/tools/git.zsh"
source "$ZSH_HOME/tools/docker.zsh"
source "$ZSH_HOME/tools/node.zsh"
source "$ZSH_HOME/tools/python.zsh"
source "$ZSH_HOME/tools/system.zsh"
source "$ZSH_HOME/tools/vscode.zsh"
source "$ZSH_HOME/tools/ai.zsh"
source "$ZSH_HOME/tools/opencode.zsh"
source "$ZSH_HOME/tools/dev-agent.zsh"

# ------------------------------------------------------------
# User Layer (Aliases & Custom Functions)
# ------------------------------------------------------------
source "$ZSH_HOME/aliases.zsh"
source "$ZSH_HOME/functions.zsh"

# ------------------------------------------------------------
# Completion System (Cached, Hardened)
# ------------------------------------------------------------
autoload -Uz compinit
if [[ -n "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"(#qN.m-1) ]]; then
  compinit -C -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
else
  compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
fi

# ============================================================
# End of Authoritative .zshrc
# ============================================================
