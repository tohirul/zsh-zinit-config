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

  local target="$root/graphify-out"
  local backup="$target.backup.$$"

  # Keep the previous graphify-out/ around (renamed aside) until the new
  # build is validated — a failed/killed `graphify` run must never leave
  # the project without a working graph.
  if [[ -e "$target" ]]; then
    mv -- "$target" "$backup" || { echo "Failed to back up existing graphify-out."; return 1; }
  fi

  local gf_rc
  if [[ -n "$backend" ]]; then
    graphify . --wiki --svg --backend "$backend" --force
  else
    graphify . --wiki --svg --force
  fi
  gf_rc=$?

  if (( gf_rc == 0 )) && _gf_validate_output "$target"; then
    rm -rf -- "$backup"
    echo "Done: $target"
    return 0
  fi

  echo "Build failed or produced invalid output; restoring previous graphify-out."
  rm -rf -- "$target"
  [[ -e "$backup" ]] && mv -- "$backup" "$target"
  return 1
}

gfupdate() {
  _gf_need graphify || return 1
  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  cd "$root" || return 1

  if ! graphify . --update; then
    echo "gfupdate: graphify --update failed."
    return 1
  fi

  _gf_validate_output "$root/graphify-out" || {
    echo "gfupdate: graphify-out failed validation after update."
    return 1
  }
}
