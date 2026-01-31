# ============================================================
# OpenCode – Agent-Orchestrated Shell Interface
# ============================================================
# This file is a thin adapter ONLY.
# All logic lives in:
#   - scripts/*.zsh
#   - SKILL.md (orchestrator)
#   - plugins/*
# ============================================================

# ------------------------------------------------------------
# Guards
# ------------------------------------------------------------

_oc_guard() {
  command -v opencode >/dev/null 2>&1 || {
    echo "[opencode] opencode not found"
    return 1
  }
}

_code_guard() {
  command -v code >/dev/null 2>&1 || {
    echo "[opencode] VS Code not found"
    return 1
  }
}

_script_guard() {
  local script="$1"
  [[ -x "$script" ]] || {
    echo "[opencode] Script not executable: $script"
    return 1
  }
}

# ------------------------------------------------------------
# Canonical Entrypoints (NO LOGIC)
# ------------------------------------------------------------

oc() {
  _oc_guard || return
  opencode .
}

ocv() {
  _code_guard || return
  code .
}

oc_root() {
  _oc_guard || return
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  opencode "$root"
}

oc_here_or_root() {
  _oc_guard || return
  git rev-parse --show-toplevel 2>/dev/null | xargs -r opencode || opencode .
}

# ------------------------------------------------------------
# Workflow-Oriented Commands (Delegation ONLY)
# ------------------------------------------------------------

oc_detect() {
  _script_guard "./scripts/detect-project.zsh" || return
  ./scripts/detect-project.zsh
}

oc_validate() {
  _script_guard "./scripts/validate-context.zsh" || return
  ./scripts/validate-context.zsh
}

oc_context_generate() {
  _script_guard "./scripts/generate-context.zsh" || return
  ./scripts/generate-context.zsh
}

oc_examples() {
  _script_guard "./scripts/select-example.zsh" || return
  ./scripts/select-example.zsh
}

oc_tasks_generate() {
  _script_guard "./scripts/generate-tasks.zsh" || return
  ./scripts/generate-tasks.zsh
}

# ------------------------------------------------------------
# Explicit Review Entrypoints (Plugin-Aligned)
# ------------------------------------------------------------

oc_review_core() {
  echo "[opencode] Core architecture review requested"
  echo "→ Use core-review plugin via OpenCode session"
  opencode .
}

oc_review_ts() {
  echo "[opencode] TypeScript review requested"
  echo "→ typescript plugin will be resolved by orchestrator"
  opencode .
}

oc_review_js() {
  echo "[opencode] JavaScript review requested"
  echo "→ javascript plugin will be resolved by orchestrator"
  opencode .
}

# ------------------------------------------------------------
# Discovery Helpers (Read-only)
# ------------------------------------------------------------

oc_projects() {
  _oc_guard || return
  command -v fzf >/dev/null 2>&1 || {
    echo "[opencode] fzf not installed"
    return 1
  }

  local dir
  dir=$(find "$HOME" -maxdepth 3 -type d -name .git 2>/dev/null \
    | sed 's|/.git||' \
    | fzf --prompt="OpenCode project > ")

  [[ -n "$dir" ]] && opencode "$dir"
}

oc_node() {
  find . -maxdepth 3 -name package.json -exec dirname {} \; \
    | fzf --prompt="Node project > " \
    | xargs -r opencode
}

oc_python() {
  find . -maxdepth 3 \
    \( -name pyproject.toml -o -name environment.yml \) \
    -exec dirname {} \; \
  | fzf --prompt="Python project > " \
  | xargs -r opencode
}

oc_docker() {
  find . -maxdepth 3 -name docker-compose.yml \
    -exec dirname {} \; \
  | fzf --prompt="Docker project > " \
  | xargs -r opencode
}
