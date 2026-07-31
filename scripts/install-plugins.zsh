#!/usr/bin/env zsh
# ============================================================
# Zinit plugin installer — pinned, explicit, manual-only
# ============================================================
# Clones/updates every plugin listed in plugins.lock at its pinned
# revision. The startup orchestrator (zsh_backuprc.zsh) never runs
# this and never clones a plugin itself — it only loads a plugin
# whose directory already exists. Run this once after cloning the
# framework, and again whenever plugins.lock changes:
#
#   zsh "$ZSH_HOME/scripts/install-plugins.zsh"
# ============================================================

ZSH_HOME="${ZSH_HOME:-$HOME/.zsh}"
ZINIT_HOME="${ZINIT_HOME:-$HOME/.local/share/zinit/zinit.git}"
LOCK_FILE="$ZSH_HOME/plugins.lock"

if [[ ! -r "$ZINIT_HOME/zinit.zsh" ]]; then
  echo "Error: zinit is not installed: $ZINIT_HOME/zinit.zsh" >&2
  echo "Run scripts/install-zinit.zsh first." >&2
  exit 1
fi

if [[ ! -r "$LOCK_FILE" ]]; then
  echo "Error: lock file not found: $LOCK_FILE" >&2
  exit 1
fi

source "$ZINIT_HOME/zinit.zsh"

typeset -i fail=0
typeset -i count=0
while IFS=' ' read -r spec pin; do
  [[ -z "$spec" || "$spec" == \#* ]] && continue
  ((count++))
  echo "Installing $spec @ $pin ..."
  zinit ice ver"$pin"
  if ! zinit light "$spec"; then
    echo "  Failed: $spec" >&2
    fail=1
    continue
  fi
  if [[ ! -d "${ZINIT_HOME:h}/plugins/${spec/\//---}" ]]; then
    echo "  Failed: $spec (directory not created)" >&2
    fail=1
  fi
done < "$LOCK_FILE"

echo
if (( fail )); then
  echo "Plugin install completed with failures ($count attempted)." >&2
  exit 1
fi

echo "All $count pinned plugins installed."
exit 0
