#!/usr/bin/env zsh
# ============================================================
# Framework bootstrap — one-time / repeatable setup
# ============================================================
# Brings a fresh clone to a fully working state, idempotently:
#   1. Installs Zinit if missing (delegates to install-zinit.zsh).
#   2. Creates $ZSH_HOME/local.zsh from local.zsh.example if absent.
#   3. Mirrors zsh_backuprc.zsh -> ~/.zshrc (backing up any old one).
#   4. Precompiles modules (.zwc) for faster startup.
#
# Safe to re-run at any time; nothing is overwritten without a backup.
# This is a manual script — the startup orchestrator never runs it.
# ============================================================

ZSH_HOME="${ZSH_HOME:-$HOME/.zsh}"

echo "== Zsh framework bootstrap =="
echo "Framework: $ZSH_HOME"

# ------------------------------------------------------------
# 1. Zinit
# ------------------------------------------------------------
if [[ -f "$ZSH_HOME/scripts/install-zinit.zsh" ]]; then
  echo
  echo "[1/4] Zinit plugin manager"
  zsh "$ZSH_HOME/scripts/install-zinit.zsh"
  zinit_rc=$?
  if (( zinit_rc != 0 )); then
    echo "  Warning: zinit install failed; framework helpers still work without it."
  fi
else
  echo "  Skipped: install-zinit.zsh not found (framework clone incomplete?)."
fi

# ------------------------------------------------------------
# 2. local.zsh (machine-local config)
# ------------------------------------------------------------
echo
echo "[2/4] Machine-local config (local.zsh)"
if [[ ! -f "$ZSH_HOME/local.zsh" ]]; then
  if [[ -f "$ZSH_HOME/local.zsh.example" ]]; then
    cp "$ZSH_HOME/local.zsh.example" "$ZSH_HOME/local.zsh"
    echo "  Created: $ZSH_HOME/local.zsh (from local.zsh.example)."
    echo "  Edit it to set AZKABAN_VAULT etc."
  else
    echo "  Skipped: local.zsh.example not found; create local.zsh manually."
  fi
else
  echo "  Already present: $ZSH_HOME/local.zsh (leaving untouched)."
fi

# ------------------------------------------------------------
# 3. ~/.zshrc mirror (authoritative: zsh_backuprc.zsh)
# ------------------------------------------------------------
echo
echo "[3/4] ~/.zshrc mirror"
rc="$HOME/.zshrc"
if [[ -f "$rc" ]] && ! cmp -s "$ZSH_HOME/zsh_backuprc.zsh" "$rc"; then
  backup="$rc.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$rc" "$backup"
  echo "  Backed up existing ~/.zshrc -> $backup"
fi
cp "$ZSH_HOME/zsh_backuprc.zsh" "$rc"
echo "  Mirrored zsh_backuprc.zsh -> $rc"

# ------------------------------------------------------------
# 4. Precompile modules
# ------------------------------------------------------------
echo
echo "[4/4] Precompile modules (.zwc)"
compiled=0
for f in "$ZSH_HOME"/lib/*.zsh "$ZSH_HOME"/tools/*.zsh "$ZSH_HOME"/tools/*/*.zsh \
         "$ZSH_HOME"/aliases.zsh "$ZSH_HOME"/functions.zsh; do
  [[ -f "$f" ]] || continue
  zcompile "$f" 2>/dev/null || true
  ((compiled++))
done
echo "  Compiled $compiled modules."

echo
echo "== Bootstrap complete =="
echo "Next: exec zsh  (and run 'zsh_audit' to verify the framework)."
