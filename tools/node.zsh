# ============================================================
# Node.js Helpers (Drop-in, Hardened, OpenCode-safe)
# Ubuntu / nvm / multi-PM / jq-guarded
# ============================================================
[[ -n ${_ZSH_TOOL_NODE:-} ]] && return
typeset -g _ZSH_TOOL_NODE=1

# ----------------------------
# Guards
# ----------------------------

_node_guard() {
  # `command -v node` would always succeed once the node() wrapper below
  # is defined (it matches functions too), so this checks for a real
  # executable instead — loading nvm first if node isn't on PATH yet.
  [[ -n "$(_node_real_command node)" ]] && return 0
  _load_nvm
  [[ -n "$(_node_real_command node)" ]] && return 0
  echo "[node] Node not available (nvm not loaded?)"
  return 1
}

_pkg_guard() {
  [[ -f package.json ]] || {
    echo "[node] package.json not found"
    return 1
  }
  if command -v jq >/dev/null 2>&1; then
    jq -e . package.json >/dev/null 2>&1 || {
      echo "[node] package.json is invalid JSON"
      return 1
    }
  fi
}

# _jq_guard is provided by lib/utils.zsh

# ----------------------------
# Lazy nvm loading
# ----------------------------
# _ZSH_NVM_LOADED (not `${+functions[nvm]}`) tracks readiness: our own
# lazy `nvm()` wrapper below is itself a function, so function-existence
# alone can't tell "not loaded yet" from "loaded" — only an explicit flag
# set right after a successful `. nvm.sh` can.

_node_nvm_ready() {
  (( ${_ZSH_NVM_LOADED:-0} ))
}

_load_nvm() {
  _node_nvm_ready && return 0
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  [[ -s "$NVM_DIR/nvm.sh" ]] || return 1
  . "$NVM_DIR/nvm.sh" || return 1
  typeset -g _ZSH_NVM_LOADED=1
  return 0
}

# Real executable on PATH, never a shell function (a wrapper of the same
# name would otherwise make `command -v` lie about availability).
_node_real_command() {
  whence -p "$1" 2>/dev/null
}

# Try the real executable first; only pay for `_load_nvm` when it's
# actually missing, and never touch/unset the calling wrapper — a failed
# load must leave the wrapper callable (and retryable) instead of
# disappearing for the rest of the session.
_node_dispatch() {
  local command_name="$1"
  shift

  local real
  real="$(_node_real_command "$command_name")"
  if [[ -n "$real" ]]; then
    "$real" "$@"
    return $?
  fi

  if ! _load_nvm; then
    echo "[node] '$command_name' not found and nvm is not available (expected \$NVM_DIR/nvm.sh)" >&2
    return 127
  fi

  real="$(_node_real_command "$command_name")"
  if [[ -z "$real" ]]; then
    echo "[node] '$command_name' still not available after loading nvm" >&2
    return 127
  fi

  "$real" "$@"
}

# Safe command wrappers
node() { _node_dispatch node "$@"; }
npm()  { _node_dispatch npm  "$@"; }
pnpm() { _node_dispatch pnpm "$@"; }
bun()  { _node_dispatch bun  "$@"; }
yarn() { _node_dispatch yarn "$@"; }

# nvm itself is a shell function, not an executable — dispatch through
# _load_nvm directly. Real nvm.sh redefines `nvm` when sourced, so the
# recursive call below resolves to the real implementation once loaded.
nvm() {
  if ! _load_nvm; then
    echo "[node] nvm not installed (expected \$NVM_DIR/nvm.sh)" >&2
    return 1
  fi
  nvm "$@"
}

nvm_use() {
  _load_nvm || {
    echo "[node] nvm not installed"
    return 1
  }
  nvm use
}

# ----------------------------
# Package manager detection
# ----------------------------

node_pm() {
  _pkg_guard || return 1
  _jq_guard  || return 1

  local spec pm

  spec=$(jq -r '.packageManager // empty' package.json)

  if [[ -n "$spec" ]]; then
    pm="${spec%%@*}"
    command -v corepack >/dev/null 2>&1 && corepack enable >/dev/null 2>&1
    echo "$pm"
    return 0
  fi

  [[ -f pnpm-lock.yaml ]] && echo pnpm && return 0
  [[ -f bun.lockb     ]] && echo bun  && return 0
  [[ -f yarn.lock     ]] && echo yarn && return 0

  echo npm
}

# ----------------------------
# Core commands
# ----------------------------

ni() {
  _pkg_guard || return 1
  local pm
  pm=$(node_pm) || return 1
  _node_dispatch "$pm" install "$@"
}

nr() {
  _pkg_guard || return 1
  local pm
  pm=$(node_pm) || return 1
  _node_dispatch "$pm" run "$@"
}

ndev()   { nr dev; }
nbuild() { nr build; }
ntest()  { nr test; }

# ----------------------------
# Version & engines
# ----------------------------

node_info() {
  _node_guard || return 1
  _pkg_guard  || return 1
  _jq_guard   || return 1

  echo "Node: $(node -v)"
  echo "PM:   $(node_pm)"

  echo "Engines:"
  jq -r '.engines // {} | to_entries[] | "  \(.key): \(.value)"' package.json
}

node_check_engines() {
  _pkg_guard || return 1
  _jq_guard  || return 1

  local required
  required=$(jq -r '.engines.node // empty' package.json)

  [[ -n "$required" ]] && echo "Required Node: $required"
}

# ----------------------------
# Cleanup (safe by default)
# ----------------------------

node_clean() {
  _pkg_guard || return 1
  rm -rf node_modules
  echo "[node] node_modules removed"
}

node_reset() {
  _pkg_guard || return 1

  [[ -n "$NODE_FORCE" ]] || {
    echo "[node] Destructive reset blocked"
    echo "[node] Re-run with NODE_FORCE=1"
    return 1
  }

  rm -rf \
    node_modules \
    package-lock.json \
    yarn.lock \
    pnpm-lock.yaml \
    bun.lockb

  ni
}

# ----------------------------
# Monorepo helpers
# ----------------------------

node_workspaces() {
  _pkg_guard || return 1
  _jq_guard  || return 1
  jq -r '.workspaces // empty' package.json
}

node_run_all() {
  _pkg_guard || return 1
  local script="$1"
  local pm
  pm=$(node_pm) || return 1

  [[ -z "$script" ]] && {
    echo "Usage: node_run_all <script>"
    return 1
  }

  case "$pm" in
    npm)  _node_dispatch npm -ws run "$script" ;;
    pnpm) _node_dispatch pnpm -r run "$script" ;;
    yarn) _node_dispatch yarn workspaces foreach run "$script" ;;
    bun)  _node_dispatch bun --filter '*' run "$script" ;;
    *)    echo "[node] Unsupported PM for workspaces: $pm"; return 1 ;;
  esac
}

# ----------------------------
# Size
# ----------------------------

node_size() {
  du -sh node_modules 2>/dev/null || echo "[node] node_modules not found"
}

# ----------------------------
# Interactive
# ----------------------------

node_script_fzf() {
  _pkg_guard || return 1
  _jq_guard  || return 1
  command -v fzf >/dev/null 2>&1 || {
    echo "[node] fzf not installed"
    return 1
  }

  local script
  script=$(jq -r '.scripts | keys[]' package.json | \
    fzf --preview 'jq -r ".scripts[\"{}\"]" package.json')

  [[ -n "$script" ]] && nr "$script"
}
