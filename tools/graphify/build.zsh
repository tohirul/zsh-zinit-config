# ============================================================
# Graphify workflow layer — full / update in-repo builds
# ============================================================
[[ -n ${_ZSH_TOOL_GRAPHIFY_BUILD:-} ]] && return
typeset -g _ZSH_TOOL_GRAPHIFY_BUILD=1

gffull() {
  _gf_need graphify || return 1

  local backend="${1:-$GRAPHIFY_DEFAULT_BACKEND}"
  local root="$(_gf_abs "${2:-$(_gf_root)}")" || return 1
  cd "$root" || return 1

  echo "Building Graphify full graph:"
  echo "  Project: $root"
  [[ -n "$backend" ]] && echo "  Backend: $backend"

  rm -rf graphify-out

  if [[ -n "$backend" ]]; then
    graphify . --wiki --svg --backend "$backend" --force
  else
    graphify . --wiki --svg --force
  fi
}

gfupdate() {
  _gf_need graphify || return 1
  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  cd "$root" || return 1
  graphify . --update
}
