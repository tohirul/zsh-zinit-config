# ============================================================
# Developer Workflow Functions
# ============================================================

# ---------- navigation ----------
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd='z'
fi

# ---------- fzf helpers ----------
fzf_cd() {
  local dir
  dir=$(find . -type d -not -path '*/\.git/*' 2>/dev/null | fzf)
  [[ -n "$dir" ]] && cd "$dir"
}

fzf_file() {
  local file
  file=$(find . -type f 2>/dev/null | fzf)
  [[ -n "$file" ]] && ${EDITOR:-nano} "$file"
}

# ---------- dev lifecycle ----------
dev_init() {
  echo "🚀 Initializing dev environment"
  command -v node >/dev/null && node -v
  command -v python >/dev/null && python --version
  command -v docker >/dev/null && docker --version
}

# In functions.zsh

dev_clean() {
  info "Cleaning multi-stack artifacts..."
  # Node/Next.js
  [[ -d node_modules ]] && rm -rf node_modules
  [[ -d .next ]] && rm -rf .next
  # Python
  find . -type d -name "__pycache__" -exec rm -rf {} +
  find . -type d -name ".pytest_cache" -exec rm -rf {} +
  # Go/General
  [[ -d dist ]] && rm -rf dist
  [[ -d build ]] && rm -rf build
  [[ -f coverage.out ]] && rm coverage.out
}

dev_health() {
  echo "🔍 Dev Health Check"
  echo "Node:   $(command -v node >/dev/null && node -v || echo missing)"
  echo "Python: $(command -v python >/dev/null && python --version || echo missing)"
  echo "Docker: $(command -v docker >/dev/null && docker --version || echo missing)"
  echo "Git:    $(command -v git >/dev/null && git --version || echo missing)"
}

# ---------- project detection ----------
project_type() {
  [[ -f package.json ]] && echo "node" && return
  [[ -f docker-compose.yml ]] && echo "docker" && return
  [[ -f environment.yml ]] && echo "conda" && return
  echo "unknown"
}

project_info() {
  echo "Project type: $(project_type)"
  [[ -f .conda-env ]] && echo "Conda env: $(<.conda-env)"
}
