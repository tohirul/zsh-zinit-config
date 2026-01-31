# ============================================================
# OpenCode – Agent-Orchestrated Shell Interface
# ============================================================
# This file is a THIN ADAPTER ONLY.
#
# All intelligence lives in:
#   - ~/.agent/skills/vscode-opencode-workflow/SKILL.md
#   - scripts/*.zsh
#   - plugins/*
#
# Shell responsibilities:
#   - Guard binaries
#   - Delegate execution
#   - Provide ergonomic entrypoints
# ============================================================

# ------------------------------------------------------------
# Canonical Workflow Location (from .zshrc)
# ------------------------------------------------------------

: "${OPENCODE_WORKFLOW_ROOT:?OPENCODE_WORKFLOW_ROOT not set}"
: "${OPENCODE_WORKFLOW_SCRIPTS:?OPENCODE_WORKFLOW_SCRIPTS not set}"

# ------------------------------------------------------------
# Guards (NO FALLBACKS)
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
    echo "[opencode] Script not executable:"
    echo "  $script"
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
  git rev-parse --show-toplevel 2>/dev/null \
    | xargs -r opencode \
    || opencode .
}

# ------------------------------------------------------------
# Workflow-Oriented Commands (DELEGATION ONLY)
# ------------------------------------------------------------

oc_detect() {
  local s="$OPENCODE_WORKFLOW_SCRIPTS/detect-project.zsh"
  _script_guard "$s" || return
  "$s"
}

oc_validate() {
  local s="$OPENCODE_WORKFLOW_SCRIPTS/validate-context.zsh"
  _script_guard "$s" || return
  "$s"
}

oc_context_generate() {
  local s="$OPENCODE_WORKFLOW_SCRIPTS/generate-context.zsh"
  _script_guard "$s" || return
  "$s"
}

oc_examples() {
  local s="$OPENCODE_WORKFLOW_SCRIPTS/select-example.zsh"
  _script_guard "$s" || return
  "$s"
}

oc_tasks_generate() {
  local s="$OPENCODE_WORKFLOW_SCRIPTS/generate-tasks.zsh"
  _script_guard "$s" || return
  "$s"
}

# ------------------------------------------------------------
# Explicit Review Entrypoints (PLUGIN-ALIGNED)
# ------------------------------------------------------------

oc_review_core() {
  echo "[opencode] Core architecture review requested"
  echo "→ core-review plugin will be resolved by orchestrator"
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
# Discovery Helpers (READ-ONLY)
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
