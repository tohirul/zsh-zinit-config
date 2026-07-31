# ============================================================
# Zsh Developer Framework — Ubuntu (Hardened, Authoritative)
# Thin orchestrator: sources modules from $ZSH_HOME, no logic here.
#
# Startup contract:
#   - No network access. No cloning. No installer execution.
#   - No eager NVM or Conda initialization. No environment activation.
#   - No global alias destruction (no `unalias -m '*'`).
#   - Machine-local configuration lives in $ZSH_HOME/local.zsh (git-ignored).
#   - Zinit must be installed explicitly via scripts/install-zinit.zsh.
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
export ZSH_HOME="${ZSH_HOME:-$HOME/.zsh}"
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"

# ------------------------------------------------------------
# History (hardened: private, shared, bounded)
# ------------------------------------------------------------
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=10000
SAVEHIST=10000

# Create the history file with restrictive permissions without changing the
# session-wide umask (restore it afterwards).
typeset _zsh_saved_umask="$(umask)"
umask 077
{ : >> "$HISTFILE"; } 2>/dev/null || true
chmod 600 "$HISTFILE" 2>/dev/null || true
umask "$_zsh_saved_umask"
unset _zsh_saved_umask

setopt APPEND_HISTORY        # each line is appended to the history file
setopt SHARE_HISTORY         # share history between sessions (see docs/security.md)
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY           # confirm history expansion before execution

# ------------------------------------------------------------
# Zinit (plugin manager)
# ------------------------------------------------------------
# Startup NEVER clones or installs Zinit. It only loads it when present.
# Install it explicitly once with: ~/.zsh/scripts/install-zinit.zsh
export ZINIT_HOME="${ZINIT_HOME:-$HOME/.local/share/zinit/zinit.git}"
typeset _ZSH_ZINIT_BIN="$ZINIT_HOME/zinit.zsh"
typeset _ZSH_ZINIT_PLUGINS_DIR="${ZINIT_HOME:h}/plugins"

if [[ -r "$_ZSH_ZINIT_BIN" ]]; then
  source "$_ZSH_ZINIT_BIN"

  # Annexes (extend zinit; required by the plugin recipes below)
  zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl

  # Core plugins (async, non-blocking)
  zinit wait lucid for \
    zsh-users/zsh-autosuggestions \
    zsh-users/zsh-completions \
    zdharma-continuum/fast-syntax-highlighting \
    junegunn/fzf \
    atload'alias cd="z"' \
    ajeetdsouza/zoxide \
    changyuheng/zsh-interactive-cd

  # history-substring-search: bind widgets only after the plugin has loaded.
  zinit wait lucid for \
    atload'bindkey "^[[A" history-substring-search-up; bindkey "^[[B" history-substring-search-down' \
    zsh-users/zsh-history-substring-search

  # Utility plugins (Oh-My-Zsh via Zinit)
  zinit wait"0a" lucid for \
    pick"plugins/sudo/sudo.plugin.zsh" ohmyzsh/ohmyzsh \
    pick"plugins/extract/extract.plugin.zsh" ohmyzsh/ohmyzsh \
    pick"plugins/colored-man-pages/colored-man-pages.plugin.zsh" ohmyzsh/ohmyzsh \
    pick"plugins/command-not-found/command-not-found.plugin.zsh" ohmyzsh/ohmyzsh \
    pick"plugins/copyfile/copyfile.plugin.zsh" ohmyzsh/ohmyzsh \
    pick"plugins/copypath/copypath.plugin.zsh" ohmyzsh/ohmyzsh \
    pick"plugins/web-search/web-search.plugin.zsh" ohmyzsh/ohmyzsh

  # Prompt — must load synchronously to stay Powerlevel10k instant-prompt compatible.
  zinit light romkatv/powerlevel10k
  [[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
else
  print -u2 -P -- "%F{yellow}[zinit] Plugin manager not found: %f$_ZSH_ZINIT_BIN"
  print -u2 -P -- "%F{yellow}[zinit] Install it once with: %f\$ZSH_HOME/scripts/install-zinit.zsh"
  print -u2 -P -- "%F{yellow}[zinit] Local framework helpers still load below.%f"
fi
unset _ZSH_ZINIT_BIN

# ------------------------------------------------------------
# External tooling integrations (each initialized exactly once)
# ------------------------------------------------------------

# fzf shell integration (keybindings/completion). The fzf binary is provided
# by the system package (e.g. /usr/bin/fzf); this sources the shell bindings
# exactly once.
if command -v fzf >/dev/null 2>&1 && (( ! ${_ZSH_FZF_SHELL:-0} )); then
  if [[ -r "$HOME/.fzf.zsh" ]]; then
    source "$HOME/.fzf.zsh"
    typeset -g _ZSH_FZF_SHELL=1
  elif [[ -r "$_ZSH_ZINIT_PLUGINS_DIR/junegunn---fzf/shell/key-bindings.zsh" ]]; then
    source "$_ZSH_ZINIT_PLUGINS_DIR/junegunn---fzf/shell/key-bindings.zsh"
    typeset -g _ZSH_FZF_SHELL=1
  fi
fi

# zoxide init runs inside the zinit zoxide plugin above (zoxide.plugin.zsh).
# It is intentionally NOT re-run here to avoid double initialization. The
# historical `cd` -> `z` replacement is restored via the plugin's atload hook.

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

unset _ZSH_ZINIT_PLUGINS_DIR

# ------------------------------------------------------------
# Framework libraries
# ------------------------------------------------------------
source "$ZSH_HOME/lib/errors.zsh"
source "$ZSH_HOME/lib/utils.zsh"

# ------------------------------------------------------------
# Tooling layers (thin adapters only; no eager NVM/Conda here)
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
# Completion system (cached, hardened, security-checked)
# ------------------------------------------------------------
typeset _zsh_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
mkdir -p "$_zsh_cache_dir" 2>/dev/null || true
autoload -Uz compinit

if [[ -n "$_zsh_cache_dir/zcompdump"(#qN.m-1) ]]; then
  # Fresh dump (built <1 day ago): fast path. Security checks ran when built.
  compinit -C -d "$_zsh_cache_dir/zcompdump"
else
  # Stale or missing dump: run the security checks (insecure completion dirs
  # are reported with actionable remediation here).
  compinit -d "$_zsh_cache_dir/zcompdump"
fi
unset _zsh_cache_dir

# ------------------------------------------------------------
# Machine-local configuration (git-ignored; overrides allowed)
# See local.zsh.example for the available knobs.
# ------------------------------------------------------------
[[ -r "$ZSH_HOME/local.zsh" ]] && source "$ZSH_HOME/local.zsh"

# ============================================================
# End of Authoritative .zshrc
# ============================================================
setopt interactivecomments
