# ============================================================
# Zsh Developer Framework — Ubuntu (Hardened, Authoritative)
# Thin orchestrator: sources modules from $ZSH_HOME, no logic here.
# ============================================================

# ------------------------------------------------------------
# Powerlevel10k instant prompt (MUST be first)
# ------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------
# Base environment
# ------------------------------------------------------------
export ZSH_HOME="$HOME/.zsh"
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"

# OpenCode workflow root (accessed only via oc_* adapters; not on PATH)
export OPENCODE_WORKFLOW_ROOT="$HOME/.agent/skills/vscode-opencode-workflow"
export OPENCODE_WORKFLOW_SCRIPTS="$OPENCODE_WORKFLOW_ROOT/scripts"

# ------------------------------------------------------------
# History (hardened, shared)
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
# Zinit (plugin manager)
# ------------------------------------------------------------
if [[ ! -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ]]; then
  mkdir -p "$HOME/.local/share/zinit"
  git clone https://github.com/zdharma-continuum/zinit.git \
    "$HOME/.local/share/zinit/zinit.git"
fi
source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"

# Annexes
zinit light-mode for \
  zdharma-continuum/zinit-annex-as-monitor \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-patch-dl

# Core plugins (async, non-blocking)
zinit wait lucid for \
  zsh-users/zsh-autosuggestions \
  zsh-users/zsh-completions \
  zsh-users/zsh-history-substring-search \
  zdharma-continuum/fast-syntax-highlighting \
  junegunn/fzf \
  ajeetdsouza/zoxide \
  changyuheng/zsh-interactive-cd

# Utility plugins (Oh-My-Zsh via Zinit)
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
# External tooling integrations
# ------------------------------------------------------------
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# ------------------------------------------------------------
# Prevent alias/function collisions (before user layer loads)
# ------------------------------------------------------------
unalias -m '*' 2>/dev/null

# ------------------------------------------------------------
# Framework libraries
# ------------------------------------------------------------
source "$ZSH_HOME/lib/errors.zsh"
source "$ZSH_HOME/lib/utils.zsh"

# ------------------------------------------------------------
# Tooling layers (thin adapters only)
# ------------------------------------------------------------
source "$ZSH_HOME/tools/git.zsh"
source "$ZSH_HOME/tools/docker.zsh"
source "$ZSH_HOME/tools/node.zsh"
source "$ZSH_HOME/tools/python.zsh"
source "$ZSH_HOME/tools/system.zsh"
source "$ZSH_HOME/tools/vscode.zsh"
source "$ZSH_HOME/tools/gpu.zsh"
source "$ZSH_HOME/tools/ai.zsh"
source "$ZSH_HOME/tools/opencode.zsh"
source "$ZSH_HOME/tools/dev-agent.zsh"
source "$ZSH_HOME/tools/audit.zsh"
source "$ZSH_HOME/tools/obsidian.zsh"
source "$ZSH_HOME/tools/graphify.zsh"

# ------------------------------------------------------------
# User layer (aliases & custom functions)
# ------------------------------------------------------------
source "$ZSH_HOME/aliases.zsh"
source "$ZSH_HOME/functions.zsh"

# ------------------------------------------------------------
# Completion system (cached, hardened)
# ------------------------------------------------------------
autoload -Uz compinit
if [[ -n "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"(#qN.m-1) ]]; then
  compinit -C -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
else
  compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
fi

# ============================================================
# Machine-local integrations (installer-managed; keep last)
# ============================================================

# nvm (node.zsh also lazy-loads nvm on demand; this keeps `node` on PATH eagerly)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/tohirul-islam/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/tohirul-islam/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/home/tohirul-islam/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/tohirul-islam/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# ------------------------------------------------------------
# zoxide — initialized LAST so its precmd hook stays last
# (this is what `zoxide doctor` expects; avoids the config warning)
# ------------------------------------------------------------
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd='z'
fi

# ============================================================
# End of Authoritative .zshrc
# ============================================================
setopt interactivecomments
