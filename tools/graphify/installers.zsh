# ============================================================
# Graphify workflow layer — install / setup / hooks
# ============================================================
# gfinstall delegates to scripts/install-graphify.sh (the network
# bootstrap lives there, out of the sourced toolset). The script is
# sourced in-session so the PATH export persists; it is also runnable
# directly from any shell.
# ============================================================
[[ -n ${_ZSH_TOOL_GRAPHIFY_INSTALLERS:-} ]] && return
typeset -g _ZSH_TOOL_GRAPHIFY_INSTALLERS=1

gfinstall() {
  local script="$ZSH_HOME/scripts/install-graphify.sh"
  if [[ ! -f "$script" ]]; then
    echo "Missing installer script: $script"
    return 1
  fi
  source "$script"
}

gfinitignore() {
  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  cd "$root" || return 1

  # Idempotent: each required entry is checked and appended independently,
  # so re-running never clobbers custom entries a user already added and
  # never needs a timestamped backup copy.
  local -a required=(
    '.git/'
    'node_modules/'
    '**/node_modules/'
    '.next/'
    '**/.next/'
    'dist/'
    'build/'
    'coverage/'
    '.cache/'
    '.turbo/'
    '.DS_Store'
    'graphify-out/'
    '.graphify-code-only/'
    '.env'
    '.env.*'
    '**/.env'
    '**/.env.*'
    '**/*secret*'
    '**/*token*'
    '**/*credentials*'
    '**/*.key'
    '**/*.pem'
    '**/*.p12'
    '**/*.pfx'
    '**/*.zip'
    '**/*.tar'
    '**/*.tar.gz'
    '**/*.7z'
    '**/*.log'
  )

  [[ -f .graphifyignore ]] || : > .graphifyignore
  local entry added=0
  for entry in "${required[@]}"; do
    grep -qxF -- "$entry" .graphifyignore 2>/dev/null || {
      print -r -- "$entry" >> .graphifyignore
      ((added++))
    }
  done
  echo "Checked: $root/.graphifyignore ($added entr$([[ $added == 1 ]] && echo y || echo ies) added)"

  [[ -f .gitignore ]] || : > .gitignore
  local gitignore_added=0
  for entry in 'graphify-out/' '.graphify-code-only/'; do
    grep -qxF -- "$entry" .gitignore 2>/dev/null || {
      print -r -- "$entry" >> .gitignore
      ((gitignore_added++))
    }
  done
  echo "Checked: $root/.gitignore ($gitignore_added entr$([[ $gitignore_added == 1 ]] && echo y || echo ies) added)"
}

gfhook() {
  _gf_need graphify || return 1
  local action="${1:-status}"
  case "$action" in
    install|uninstall|status)
      graphify hook "$action"
      ;;
    *)
      echo "Usage: gfhook install|uninstall|status"
      return 1
      ;;
  esac
}

gfagents() {
  _gf_need graphify || return 1

  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  cd "$root" || return 1

  echo "Installing Graphify assistant instructions in:"
  echo "  $root"

  local -a failed=()
  graphify claude install 2>/dev/null || graphify install --project 2>/dev/null || failed+=(claude)
  graphify codex install 2>/dev/null || graphify install --platform codex --project 2>/dev/null || failed+=(codex)
  graphify opencode install 2>/dev/null || graphify install --platform opencode --project 2>/dev/null || failed+=(opencode)

  echo "Check changes:"
  echo "  git status --short"

  if (( ${#failed[@]} )); then
    echo "Failed to install instructions for: ${failed[*]}"
    return 1
  fi
}
