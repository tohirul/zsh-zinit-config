# ============================================================
# Node.js Helpers (Ubuntu, nvm, multi-PM)
# ============================================================

# ---------- guards ----------
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
}

# ---------- lazy nvm ----------
# In tools/node.zsh
# Define commands that trigger nvm loading
_load_nvm() {
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}

# Create wrapper functions for lazy activation
nvm() { unset -f nvm; __load_nvm; nvm "$@" }
node() { unset -f node; __load_nvm; node "$@" }
npm() { unset -f npm; __load_nvm; npm "$@" }
pnpm() { unset -f pnpm; __load_nvm; pnpm "$@" }
bun() { unset -f bun; __load_nvm; bun "$@" }

nvm_use() {
  _load_nvm || {
    echo "[node] nvm not installed"
    return 1
  }
  nvm use
}

# ---------- package manager detection ----------
node_pm() {
  _pkg_guard || return 1

  local pm
  pm=$(jq -r '.packageManager // empty' package.json 2>/dev/null)

  if [[ -n "$pm" ]]; then
    echo "${pm%%@*}"
    return
  fi

  [[ -f pnpm-lock.yaml ]] && echo pnpm && return
  [[ -f bun.lockb ]] && echo bun && return
  [[ -f yarn.lock ]] && echo yarn && return
  echo npm
}

# ---------- core ----------
ni() {
  _pkg_guard || return
  local pm=$(node_pm)
  $pm install "$@"
}

nr() {
  _pkg_guard || return
  local pm=$(node_pm)
  $pm run "$@"
}

ndev() {
  nr dev
}

nbuild() {
  nr build
}

ntest() {
  nr test
}

# ---------- version & engines ----------
node_info() {
  _node_guard || return
  _pkg_guard || return

  echo "Node: $(node -v)"
  echo "PM: $(node_pm)"

  jq -r '.engines // empty' package.json 2>/dev/null
}

node_check_engines() {
  _pkg_guard || return
  local required
  required=$(jq -r '.engines.node // empty' package.json)
  [[ -n "$required" ]] && echo "Required Node: $required"
}

# ---------- cleanup (safe) ----------
node_clean() {
  _pkg_guard || return
  rm -rf node_modules
  echo "node_modules removed"
}

node_reset() {
  _pkg_guard || return
  echo "Resetting dependencies…"
  rm -rf node_modules \
    package-lock.json \
    yarn.lock \
    pnpm-lock.yaml \
    bun.lockb
  ni
}

# ---------- monorepo ----------
node_workspaces() {
  _pkg_guard || return
  jq -r '.workspaces // empty' package.json
}

node_run_all() {
  _pkg_guard || return
  local script="$1"
  local pm=$(node_pm)
  [[ -z "$script" ]] && {
    echo "Usage: node_run_all <script>"
    return 1
  }
  $pm -ws run "$script"
}

# ---------- size ----------
node_size() {
  du -sh node_modules 2>/dev/null || echo "node_modules not found"
}

# ---------- interactive ----------
node_script_fzf() {
  _pkg_guard || return
  local script
  script=$(jq -r '.scripts | keys[]' package.json | fzf)
  [[ -n "$script" ]] && nr "$script"
}
