# ============================================================
# Agent-Orchestrated Workflow Commands (DROP-IN)
# ============================================================
# Shell = guards + delegation ONLY
# Intelligence lives in model-orchestrator
# ============================================================
[[ -n ${_ZSH_TOOL_DEV_AGENT:-} ]] && return
typeset -g _ZSH_TOOL_DEV_AGENT=1

# ------------------------------------------------------------
# Guards (AUTHORITATIVE)
# ------------------------------------------------------------

_agent_guard() {
  _workflow_guard || return 1

  [[ -f "ai.project.json" ]] || {
    echo "[agent] ERROR: Missing ai.project.json in $(pwd)"
    echo "→ run: oc_context_generate"
    return 1
  }

  local contract_file="$OPENCODE_WORKFLOW_ROOT/CONTRACT.md"
  [[ -f "$contract_file" ]] || {
    echo "[agent] ERROR: Missing CONTRACT.md:"
    echo "  $contract_file"
    echo "→ point OPENCODE_WORKFLOW_ROOT at a checked-out workflow"
    echo "  (set in $ZSH_HOME/local.zsh, see local.zsh.example)"
    return 1
  }

  # Optional hash-lock enforcement
  if [[ -f "$OPENCODE_WORKFLOW_ROOT/.contract.sha256" ]]; then
    command -v sha256sum >/dev/null 2>&1 || {
      echo "[agent] ERROR: sha256sum not found"
      return 1
    }
    local current locked
    current=$(sha256sum "$contract_file" | awk '{print $1}')
    locked=$(awk '{print $1}' "$OPENCODE_WORKFLOW_ROOT/.contract.sha256")

    [[ "$current" != "$locked" ]] && {
      echo "[agent] ERROR: CONTRACT.md hash mismatch (governance violation)"
      echo "  expected: $locked"
      echo "  current:  $current"
      echo "→ refresh the lock only after an approved contract change:"
      echo "  oc_contract_verify > $OPENCODE_WORKFLOW_ROOT/.contract.sha256"
      return 1
    }
  fi
}

# AGENT_SCOPE validation for write-intent commands (relative, non-escaping)
_scope_guard() {
  [[ -n "$AGENT_SCOPE" ]] || {
    echo "[agent] ERROR: AGENT_SCOPE is empty"
    echo "Example:"
    echo "  export AGENT_SCOPE='src/domain/*'"
    return 1
  }
  if [[ "$AGENT_SCOPE" == /* || "$AGENT_SCOPE" == *..* ]]; then
    echo "[agent] ERROR: AGENT_SCOPE must be a relative path without '..':"
    echo "  got: $AGENT_SCOPE"
    return 1
  fi
  return 0
}

# ------------------------------------------------------------
# Canonical Entry
# ------------------------------------------------------------

agent_open() {
  _agent_guard || return
  oc_existing
}

# ------------------------------------------------------------
# Detection (Phase 1)
# ------------------------------------------------------------

agent_detect() {
  oc_detect
}

# ------------------------------------------------------------
# Context Creation (Phase 2)
# ------------------------------------------------------------

agent_context() {
  oc_context_generate
}

# ------------------------------------------------------------
# Context Validation (Phase 3)
# ------------------------------------------------------------

agent_validate() {
  oc_validate
}

# ------------------------------------------------------------
# Schema / Domain Research (READ-ONLY)
# ------------------------------------------------------------

agent_schema_research() {
  _agent_guard || return

  [[ -z "$1" ]] && {
    echo "[agent] Usage:"
    echo "  agent_schema_research <url|reference>"
    return 1
  }

  local -x AGENT_INTENT="research"
  local -x AGENT_INPUT="$1"

  echo "[agent] Schema research (read-only)"
  echo "→ intent: research"
  echo "→ no writes, no SAVE"

  opencode .
}

# ------------------------------------------------------------
# Schema Validation (READ-ONLY REVIEW)
# ------------------------------------------------------------

agent_schema_validate() {
  _agent_guard || return

  local -x AGENT_INTENT="code_review"
  local -x AGENT_SCOPE="schema"

  echo "[agent] Schema validation"
  echo "→ intent: code_review"
  echo "→ diff / read-only"

  opencode .
}

# ------------------------------------------------------------
# Schema Generation (WRITE — EXPLICIT SCOPE REQUIRED)
# ------------------------------------------------------------

agent_schema_generate() {
  _agent_guard || return
  _scope_guard || return

  local -x AGENT_INTENT="code_generation"

  echo "[agent] Schema generation"
  echo "→ intent: code_generation"
  echo "→ scope: $AGENT_SCOPE"
  echo "→ SAVE forbidden until verification"

  opencode .
}

# ------------------------------------------------------------
# Architecture / Domain Design (ADR REQUIRED)
# ------------------------------------------------------------

agent_schema_architecture() {
  _agent_guard || return

  local -x AGENT_INTENT="architecture"

  echo "[agent] Architecture intent detected"
  echo "→ ADR required"
  echo "→ no code generation"

  opencode .
}

# ------------------------------------------------------------
# Refactor (STRICT, CANARY REQUIRED)
# ------------------------------------------------------------

agent_refactor() {
  _agent_guard || return
  _scope_guard || return

  local -x AGENT_INTENT="refactor"

  echo "[agent] Refactor request"
  echo "→ intent: refactor"
  echo "→ canary execution required"
  echo "→ scope: $AGENT_SCOPE"

  opencode .
}

# ------------------------------------------------------------
# Review (Diff-Only)
# ------------------------------------------------------------

agent_review() {
  _agent_guard || return

  local -x AGENT_INTENT="code_review"

  echo "[agent] Review requested"
  echo "→ diff-only"
  echo "→ no new changes"

  opencode .
}
