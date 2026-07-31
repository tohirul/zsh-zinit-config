# ============================================================
# Obsidian / Azkaban — vault git sync
# ============================================================
[[ -n ${_ZSH_TOOL_OBSIDIAN_SYNC:-} ]] && return
typeset -g _ZSH_TOOL_OBSIDIAN_SYNC=1

obs-sync() {
  _obs_require_vault || return 1

  local dry_run=0
  local msg="vault sync: $(_obs_datetime)"
  local arg

  for arg in "$@"; do
    case "$arg" in
      --dry-run|-n) dry_run=1 ;;
      *) msg="$arg" ;;
    esac
  done

  if [[ ! -d "$AZKABAN_VAULT/.git" ]]; then
    _obs_err "Vault is not a Git repository: $AZKABAN_VAULT"
    return 1
  fi

  if (( dry_run )); then
    _obs_info "Dry run — showing pending changes (nothing committed):"
    git -C "$AZKABAN_VAULT" status --short
    return 0
  fi

  _obs_info "Syncing Azkaban vault..."

  git -C "$AZKABAN_VAULT" add -A || {
    _obs_err "Failed to stage vault changes (git add)."
    return 1
  }

  if ! git -C "$AZKABAN_VAULT" diff --cached --quiet; then
    git -C "$AZKABAN_VAULT" commit -m "$msg" || {
      _obs_err "Vault commit failed."
      return 1
    }
  else
    _obs_info "No local changes to commit."
  fi

  if git -C "$AZKABAN_VAULT" remote get-url origin >/dev/null 2>&1; then
    git -C "$AZKABAN_VAULT" pull --rebase --autostash || {
      _obs_err "Vault pull/rebase failed (possible conflict — resolve manually in $AZKABAN_VAULT)."
      return 1
    }
    git -C "$AZKABAN_VAULT" push || {
      _obs_err "Vault push failed."
      return 1
    }
    _obs_ok "Vault synced."
  else
    _obs_info "No Git remote configured. Local commit/check complete."
  fi
}
