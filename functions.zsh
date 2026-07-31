# ============================================================
# Developer Workflow Functions
# ============================================================
[[ -n ${_ZSH_FUNCTIONS:-} ]] && return
typeset -g _ZSH_FUNCTIONS=1

# NOTE: zoxide is initialized once by the zinit zoxide plugin (zoxide.plugin.zsh),
# and the `cd` -> `z` replacement is restored via that plugin's atload hook.
# It is intentionally not re-initialized here to avoid double init.

# ---------- fzf helpers ----------
fzf_cd() {
  _fzf_guard || return 1
  local dir
  dir=$(find . -type d \
    \( -name '.git' -o -name 'node_modules' -o -name '.venv' -o -name 'venv' \) \
    -prune -o -type d -print 2>/dev/null | fzf)
  [[ -n "$dir" ]] && cd "$dir"
}

fzf_file() {
  _fzf_guard || return 1
  local file
  file=$(find . -type f \
    \( -path './.git/*' -o -path './node_modules/*' -o -path './.venv/*' -o -path './venv/*' \) \
    -prune -o -type f -print 2>/dev/null | fzf)
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

# dev_clean — removes build/cache artifacts. Safe by default: it only prints
# what would be removed unless --force/-f is given. Never deletes source dirs.
dev_clean() {
  local mode="dry-run"
  case "$1" in
    -f|--force) mode="exec" ;;
    -n|--dry-run) mode="dry-run" ;;
    -h|--help)
      echo "Usage: dev_clean [-n|--dry-run] [-f|--force]"
      echo "  Removes multi-stack build/cache artifacts."
      echo "  Without --force only lists what would be removed."
      return 0
      ;;
  esac

  local targets=(
    node_modules
    .next
    dist
    build
    coverage.out
  )

  [[ "$mode" == "exec" ]] && info "Cleaning multi-stack artifacts..."
  [[ "$mode" == "dry-run" ]] && warn "Dry-run: use --force to actually remove."

  local t rc=0
  for t in "${targets[@]}"; do
    if [[ -e "$t" ]]; then
      if [[ "$mode" == "exec" ]]; then
        rm -rf -- "$t"
        info "Removed $t"
      else
        echo "  would remove: $t"
      fi
    fi
  done

  # Python caches: find-based, always scoped to the current project.
  local dirs=()
  find . -type d \
    \( -name '__pycache__' -o -name '.pytest_cache' \) \
    -not -path './node_modules/*' -not -path './.git/*' \
    -print0 2>/dev/null |
  while IFS= read -r -d '' d; do
    if [[ "$mode" == "exec" ]]; then
      rm -rf -- "$d"
      info "Removed $d"
    else
      echo "  would remove: $d"
    fi
  done

  return "$rc"
}

# dev_health — authoritative tooling status. Exit code 0 when every required
# tool is present, 1 otherwise. (Single canonical definition; the duplicate in
# tools/system.zsh has been removed.)
dev_health() {
  echo "🔎 Dev environment health"
  local t version missing=0

  for t in node python docker git; do
    if command -v "$t" >/dev/null 2>&1; then
      version=$("$t" --version 2>/dev/null | head -1)
      print -P "  %F{green}OK%f      $t  (${version:-available})"
    else
      print -P "  %F{red}MISSING%f $t"
      missing=1
    fi
  done

  [[ "$missing" -eq 0 ]] && echo "All required tools present."
  return "$missing"
}

# ---------- project detection ----------
project_type() {
  [[ -f package.json ]] && echo "node" && return
  [[ -f Cargo.toml ]] && echo "rust" && return
  [[ -f go.mod ]] && echo "go" && return
  for f in compose.yaml compose.yml docker-compose.yml docker-compose.yaml; do
    [[ -f "$f" ]] && echo "docker" && return
  done
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
