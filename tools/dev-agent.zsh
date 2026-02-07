# ============================================================
# Agent-Orchestrated Workflow Commands (DROP-IN)
# ============================================================
# Shell = guards + delegation ONLY
# Intelligence lives in model-orchestrator
# ============================================================

# ------------------------------------------------------------
# Guards (AUTHORITATIVE)
# ------------------------------------------------------------

_agent_guard() {
  [[ -f "ai.project.json" ]] || {
    echo "[agent] Missing ai.project.json"
    echo "→ run: oc_context_generate"
    return 1
  }

  [[ -f "$OPENCODE_WORKFLOW_ROOT/CONTRACT.md" ]] || {
    echo "[agent] Missing CONTRACT.md"
    return 1
  }

  # Optional hash-lock enforcement
  if [[ -f "$OPENCODE_WORKFLOW_ROOT/.contract.sha256" ]]; then
    local current locked
    current=$(sha256sum "$OPENCODE_WORKFLOW_ROOT/CONTRACT.md" | awk '{print $1}')
    locked=$(cat "$OPENCODE_WORKFLOW_ROOT/.contract.sha256")

    [[ "$current" != "$locked" ]] && {
      echo "[agent] CONTRACT.md hash mismatch"
      echo "→ governance violation"
      return 1
    }
  fi
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

  export AGENT_INTENT="research"
  export AGENT_INPUT="$1"

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

  export AGENT_INTENT="code_review"
  export AGENT_SCOPE="schema"

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

  [[ -z "$AGENT_SCOPE" ]] && {
    echo "[agent] Missing AGENT_SCOPE"
    echo "Example:"
    echo "  export AGENT_SCOPE='src/schema/*'"
    return 1
  }

  export AGENT_INTENT="code_generation"

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

  export AGENT_INTENT="architecture"

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

  [[ -z "$AGENT_SCOPE" ]] && {
    echo "[agent] Missing AGENT_SCOPE"
    echo "Example:"
    echo "  export AGENT_SCOPE='src/domain/*'"
    return 1
  }

  export AGENT_INTENT="refactor"

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

  export AGENT_INTENT="code_review"

  echo "[agent] Review requested"
  echo "→ diff-only"
  echo "→ no new changes"

  opencode .
}
