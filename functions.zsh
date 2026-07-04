# ============================================================
# Developer Workflow Functions
# ============================================================
[[ -n ${_ZSH_FUNCTIONS:-} ]] && return
typeset -g _ZSH_FUNCTIONS=1

# NOTE: zoxide is initialized once at the end of ~/.zshrc (not here) so its
# precmd hook stays last, which is what `zoxide doctor` expects.

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

# Private helper for md2pdf (file scope, not leaked as a global on each call)
_md2pdf_convert_one() {
  local md_file="$1"
  local pdf_file="$2"
  local engine="${MD2PDF_ENGINE:-xelatex}"
  local font="${MD2PDF_FONT:-Noto Sans}"

  mkdir -p "$(dirname "$pdf_file")"

  echo "Converting: $md_file -> $pdf_file"

  pandoc "$md_file" \
    --standalone \
    --from markdown+yaml_metadata_block+smart \
    --pdf-engine="$engine" \
    --resource-path="$(dirname "$md_file"):." \
    -V mainfont="$font" \
    -V sansfont="$font" \
    -V monofont="Noto Sans Mono" \
    -V geometry:margin=1in \
    -V colorlinks=true \
    -V linkcolor=blue \
    -V urlcolor=blue \
    --toc \
    -o "$pdf_file"
}

md2pdf() {
  local input="$1"
  local output="$2"

  if [[ -z "$input" ]]; then
    echo "Usage:"
    echo "  md2pdf file.md"
    echo "  md2pdf file.md output.pdf"
    echo "  md2pdf ./docs ./pdf-output"
    return 1
  fi

  if ! command -v pandoc >/dev/null 2>&1; then
    echo "Error: pandoc is not installed."
    echo "Install with:"
    echo "  sudo apt install pandoc texlive-xetex texlive-latex-extra fonts-noto-core fonts-noto-extra"
    return 1
  fi

  if [[ -f "$input" ]]; then
    if [[ "$input" != *.md ]]; then
      echo "Error: input file must be a .md file"
      return 1
    fi

    if [[ -z "$output" ]]; then
      output="${input%.md}.pdf"
    elif [[ -d "$output" ]]; then
      output="$output/$(basename "${input%.md}.pdf")"
    fi

    _md2pdf_convert_one "$input" "$output"

  elif [[ -d "$input" ]]; then
    if [[ -z "$output" ]]; then
      output="./pdf-output"
    fi

    find "$input" \
      -type f \
      -name "*.md" \
      ! -path "*/node_modules/*" \
      ! -path "*/.git/*" \
      -print0 |
    while IFS= read -r -d '' md_file; do
      local rel_path="${md_file#$input/}"
      local pdf_file="$output/${rel_path%.md}.pdf"
      _md2pdf_convert_one "$md_file" "$pdf_file"
    done

  else
    echo "Error: input not found: $input"
    return 1
  fi
}
