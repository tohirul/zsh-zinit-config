# ============================================================
# OpenCode – Agent-Orchestrated Shell Interface
# ============================================================
# THIN ADAPTER ONLY
#
# Intelligence lives in:
#   - ~/.agent/skills/vscode-opencode-workflow/SKILL.md
#   - ~/.agent/skills/vscode-opencode-workflow/CONTRACT.md
#   - scripts/*.zsh
#   - plugins/*
#
# Shell responsibilities:
#   - Guard binaries
#   - Guard workflow presence
#   - Delegate execution
#   - Provide ergonomic entrypoints
# ============================================================

# ------------------------------------------------------------
# Guards (NO FALLBACKS, NO INFERENCE)
# ------------------------------------------------------------

_oc_guard() {
  command -v opencode >/dev/null 2>&1 || {
    echo "[opencode] ERROR: opencode not found"
    return 1
  }
}

_code_guard() {
  command -v code >/dev/null 2>&1 || {
    echo "[opencode] ERROR: VS Code not found"
    return 1
  }
}

_workflow_guard() {
  [[ -d "$OPENCODE_WORKFLOW_ROOT" ]] || {
    echo "[opencode] ERROR: Workflow root not found:"
    echo "  $OPENCODE_WORKFLOW_ROOT"
    return 1
  }
}

_script_guard() {
  local script="$1"
  [[ -x "$script" ]] || {
    echo "[opencode] ERROR: Script not executable:"
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
  _workflow_guard || return
  local s="$OPENCODE_WORKFLOW_SCRIPTS/detect-project.zsh"
  _script_guard "$s" || return
  "$s"
}

oc_validate() {
  _workflow_guard || return
  local s="$OPENCODE_WORKFLOW_SCRIPTS/validate-context.zsh"
  _script_guard "$s" || return
  "$s"
}

oc_context_generate() {
  _workflow_guard || return
  local s="$OPENCODE_WORKFLOW_SCRIPTS/generate-context.zsh"
  _script_guard "$s" || return
  "$s"
}

oc_examples() {
  _workflow_guard || return
  local s="$OPENCODE_WORKFLOW_SCRIPTS/select-example.zsh"
  _script_guard "$s" || return
  "$s"
}

oc_tasks_generate() {
  _workflow_guard || return
  local s="$OPENCODE_WORKFLOW_SCRIPTS/generate-tasks.zsh"
  _script_guard "$s" || return
  "$s"
}


# ------------------------------------------------------------
# Discovery Helpers (READ-ONLY, NON-AUTHORITATIVE)
# ------------------------------------------------------------

oc_projects() {
  _oc_guard || return
  command -v fzf >/dev/null 2>&1 || {
    echo "[opencode] ERROR: fzf not installed"
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

oc_new() {
  echo "[workflow] New project initialization"

  oc_detect || return 1

  if [[ -f ai.project.json ]]; then
    echo "[workflow] ai.project.json already exists"
    echo "→ use oc_existing instead"
    return 1
  fi

  oc_context_generate || return 1

  echo
  echo "✔ ai.project.json generated"
  echo "✋ Fill required fields, then run:"
  echo "   oc_validate"
}

oc_existing() {
  echo "[workflow] Existing project entry"

  oc_detect || return 1
  oc_validate || return 1

  echo "✔ Context validated"
  echo "→ Opening OpenCode session"

  opencode .
}

oc_arch() {
  echo "[workflow] Architecture / Domain workflow"

  oc_existing || return 1

  echo "⚠ Architecture intent detected"
  echo "→ ADR REQUIRED"
  echo "→ Gemini 2.5 Pro only"

  opencode .
}

oc_plan() {
  echo "[workflow] Planning phase (non-executing)"

  oc_existing || return 1

  echo "⚠ Planning only"
  echo "→ No code writes"
  echo "→ No SAVE"

  opencode .
}

oc_impl() {
  echo "[workflow] Implementation / Refactor"

  oc_existing || return 1

  echo "⚠ Canary execution REQUIRED"
  echo "⚠ Diff-scoped only"
  echo "⚠ Devstral2 only"

  opencode .
}

oc_review_core() {
  echo "[workflow] Core review (read-only)"
  echo "→ core-review plugin"

  oc_existing || return 1
  opencode .
}

oc_review_ts() {
  echo "[workflow] TypeScript review"
  oc_existing || return 1
  opencode .
}

oc_review_js() {
  echo "[workflow] JavaScript review"
  oc_existing || return 1
  opencode .
}


oc_save() {
  echo "❌ SAVE cannot be triggered from shell"
  echo "→ Allowed only after verification"
}

oc_check() {
  oc_detect && oc_validate
}

oc_contract_verify() {
  sha256sum "$OPENCODE_WORKFLOW_ROOT/CONTRACT.md"
}
