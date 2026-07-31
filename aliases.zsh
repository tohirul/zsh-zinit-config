# ============================================================
# Aliases (Ubuntu, Safe, No Function Collisions)
# ============================================================
[[ -n ${_ZSH_ALIASES:-} ]] && return
typeset -g _ZSH_ALIASES=1

# ----- core -----
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'

# ----- ls replacements -----
if command -v eza >/dev/null 2>&1; then
  alias ls='eza'
  alias ll='eza -la --icons'
  alias lt='eza --tree --icons'
else
  alias ll='ls -la'
fi

# ----- cat replacement -----
command -v bat >/dev/null 2>&1 && alias cat='bat'

# ----- git (NON-conflicting only) -----
alias g='git'
alias ga='git add'
alias gc='git commit'
# NOTE: gca is a function in tools/git.zsh (git commit --amend); no alias here to avoid shadowing.

# ----- docker -----
alias d='docker'
alias dc='docker compose'

# ----- python -----
alias py='python'

# ----- system -----
alias ports='ss -tulpn'
alias dfh='df -h'
alias duh='du -sh'

# ----- safety -----
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
