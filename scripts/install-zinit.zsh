#!/usr/bin/env zsh
# ============================================================
# Zinit plugin manager — one-time installer
# ============================================================
# The startup orchestrator NEVER installs zinit (no network, no cloning
# at load time). Run this explicitly when zinit is missing:
#
#   zsh "$ZSH_HOME/scripts/install-zinit.zsh"
#
# Uses the same ZINIT_HOME default as zsh_backuprc.zsh, so an override in
# local.zsh is respected here as well.
# ============================================================

ZINIT_HOME="${ZINIT_HOME:-$HOME/.local/share/zinit/zinit.git}"

if [[ -r "$ZINIT_HOME/zinit.zsh" ]]; then
  echo "Zinit already installed: $ZINIT_HOME/zinit.zsh"
  echo "Nothing to do. Restart your terminal (or: exec zsh) to load plugins."
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required to install zinit." >&2
  exit 1
fi

echo "Installing Zinit into: $ZINIT_HOME"
mkdir -p "${ZINIT_HOME:h}"
git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"

if [[ -r "$ZINIT_HOME/zinit.zsh" ]]; then
  echo
  echo "Zinit installed."
  echo "Restart your terminal (or: exec zsh) to load plugins."
else
  echo "Install failed: $ZINIT_HOME/zinit.zsh missing." >&2
  echo "Check the git clone above." >&2
  exit 1
fi
