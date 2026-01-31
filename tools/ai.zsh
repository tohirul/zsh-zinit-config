# ============================================================
# AI Agent Integration (OpenCode + OmO)
# ============================================================

# ---------- OpenCode Guards ----------
_opencode_guard() {
  command -v opencode >/dev/null 2>&1 || {
    warn "OpenCode binary not found in PATH"
    return 1
  }
}

# ---------- AI Workflow Aliases ----------
# Natural Language to Shell
alias ask='_opencode_guard && opencode ask' 

# Next.js/TS Component Generation
alias gen='_opencode_guard && opencode gen --stack nextjs-ts'

# Oh My OpenCode (Multi-Agent Orchestrator)
alias omo='bunx oh-my-opencode'
alias ulw='omo ultrawork'      # High-density refactoring
alias omo-fix='omo fix'        # AI-driven bug resolution

# ---------- Context Syncing ----------
# Syncs current shell state to Clawdbot/OmO memory
ai_sync() {
  local mem_dir="${HOME}/clawd"
  mkdir -p "$mem_dir"
  echo "TIMESTAMP: $(date)" > "$mem_dir/CONTEXT.tmp"
  echo "PROJECT: $(project_type)" >> "$mem_dir/CONTEXT.tmp"
  echo "BRANCH: $(git rev-parse --abbrev-ref HEAD 2>/dev/null)" >> "$mem_dir/CONTEXT.tmp"
  info "Context synced for AI agents."
}
