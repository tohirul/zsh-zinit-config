[[ -n ${_ZSH_LIB_UTILS:-} ]] && return
typeset -g _ZSH_LIB_UTILS=1

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Shared guards (used across tool modules)
_jq_guard() {
  command -v jq >/dev/null 2>&1 || {
    echo "[utils] jq is required but not installed"
    return 1
  }
}

_code_guard() {
  command -v code >/dev/null 2>&1 || {
    echo "[utils] 'code' command not found (install VS Code + enable shell command)"
    return 1
  }
}

_fzf_guard() {
  command -v fzf >/dev/null 2>&1 || {
    echo "[utils] fzf is required but not installed"
    return 1
  }
}
