# ============================================================
# Node.js Helpers (Drop-in, Hardened, OpenCode-safe)
# Ubuntu / nvm / multi-PM / jq-guarded
# ============================================================

# ----------------------------
# Guards
# ----------------------------

_node_guard() {
  command -v node >/dev/null 2>&1 || {
    echo "[node] Node not available (nvm not loaded?)"
    return 1
  }
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

_jq_guard() {
  command -v jq >/dev/null 2>&1 || {
    echo "[node] jq is required but not installed"
    return 1
  }
}

# ----------------------------
# Lazy nvm loading
# ----------------------------

_load_nvm() {
  export NVM_DIR="$HOME/.nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] || return 1
  . "$NVM_DIR/nvm.sh"
}

# Safe command wrappers
node() { unset -f node; _load_nvm; command -v node >/dev/null && command node "$@" || return 127; }
npm()  { unset -f npm;  _load_nvm; command -v npm  >/dev/null && command npm  "$@" || return 127; }
pnpm() { unset -f pnpm; _load_nvm; command -v pnpm >/dev/null && command pnpm "$@" || return 127; }
bun()  { unset -f bun;  _load_nvm; command -v bun  >/dev/null && command bun  "$@" || return 127; }
nvm()  { unset -f nvm;  _load_nvm || return 127; nvm  "$@"; }

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
  command "$pm" install "$@"
}

nr() {
  _pkg_guard || return 1
  local pm
  pm=$(node_pm) || return 1
  command "$pm" run "$@"
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
    npm)  command npm -ws run "$script" ;;
    pnpm) command pnpm -r run "$script" ;;
    yarn) command yarn workspaces foreach run "$script" ;;
    bun)  command bun --filter '*' run "$script" ;;
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
