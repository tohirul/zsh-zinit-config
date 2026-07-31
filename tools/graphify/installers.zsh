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

  [[ -f .graphifyignore ]] && cp .graphifyignore ".graphifyignore.bak.$(date +%Y%m%d-%H%M%S)"

  cat > .graphifyignore <<'EOF'
# Graphify ignores
.git/
node_modules/
**/node_modules/
.next/
**/.next/
dist/
build/
coverage/
.cache/
.turbo/
.DS_Store

# Graphify runtime
graphify-out/
.graphify-code-only/

# Secrets / local env
.env
.env.*
**/.env
**/.env.*
**/*secret*
**/*token*
**/*.key
**/*.pem

# Heavy/generated files
**/*.zip
**/*.tar
**/*.tar.gz
**/*.7z
**/*.log
EOF

  grep -qxF 'graphify-out/' .gitignore 2>/dev/null || cat >> .gitignore <<'EOF'

# Graphify local outputs
graphify-out/
.graphify-code-only/
EOF

  echo "Created: $root/.graphifyignore"
  echo "Updated: $root/.gitignore"
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

  graphify claude install 2>/dev/null || graphify install --project 2>/dev/null || true
  graphify codex install 2>/dev/null || graphify install --platform codex --project 2>/dev/null || true
  graphify opencode install 2>/dev/null || graphify install --platform opencode --project 2>/dev/null || true

  echo "Check changes:"
  echo "  git status --short"
}
