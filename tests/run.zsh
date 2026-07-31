#!/usr/bin/env zsh
# ============================================================
# Test runner — usage: zsh tests/run.zsh
# ============================================================
# Hermetic: sources only the tool loaders under test, never
# zsh_backuprc.zsh (which would touch zinit / live shell state).
# All cases run in temp dirs; nothing outside the repo is modified.
# ============================================================

REPO_ROOT="${0:A:h:h}"
export ZSH_HOME="$REPO_ROOT"

source "$ZSH_HOME/tests/test_helper.zsh"
source "$ZSH_HOME/tools/obsidian.zsh"
source "$ZSH_HOME/tools/graphify.zsh"

for case in "$ZSH_HOME"/tests/cases/*.zsh; do
  [[ -f "$case" ]] || continue
  print -r -- ""
  print -r -- "########## $(basename "$case") ##########"
  source "$case"
done

_t_summary
