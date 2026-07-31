# ============================================================
# Graphify workflow layer — open / inspect / query
# ============================================================
[[ -n ${_ZSH_TOOL_GRAPHIFY_QUERY:-} ]] && return
typeset -g _ZSH_TOOL_GRAPHIFY_QUERY=1

gfopen() {
  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  local html="$root/graphify-out/graph.html"
  local json="$root/graphify-out/graph.json"

  if [[ ! -f "$json" ]]; then
    echo "No graph found at: $json"
    echo "Run:"
    echo "  gfcode"
    return 1
  fi

  if [[ ! -f "$html" ]]; then
    echo "graph.json exists, but graph.html is missing:"
    echo "  $html"
    echo
    echo "Try:"
    echo "  graphify cluster-only \"$root\""
    echo
    echo "Or inspect JSON:"
    echo "  gfjson"
    return 1
  fi

  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$html" >/dev/null 2>&1 && return 0
  fi

  if command -v sensible-browser >/dev/null 2>&1; then
    sensible-browser "$html" >/dev/null 2>&1 && return 0
  fi

  if command -v google-chrome >/dev/null 2>&1; then
    google-chrome "$html" >/dev/null 2>&1 & disown
    return 0
  fi

  echo "Open manually:"
  echo "  $html"
}

gfreport() {
  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  [[ -f "$root/graphify-out/GRAPH_REPORT.md" ]] || {
    echo "Missing report: $root/graphify-out/GRAPH_REPORT.md"
    return 1
  }
  sed -n '1,240p' "$root/graphify-out/GRAPH_REPORT.md"
}

gfjson() {
  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  _gf_require_graph "$root" || return 1
  less "$root/graphify-out/graph.json"
}

gfq() {
  _gf_need graphify || return 1
  local q="$*"
  [[ -n "$q" ]] || {
    echo 'Usage: gfq "question about this project"'
    return 1
  }
  _gf_require_graph "$(_gf_root)" || return 1
  graphify query "$q"
}

gfpath() {
  _gf_need graphify || return 1
  [[ $# -ge 2 ]] || {
    echo 'Usage: gfpath "node A" "node B"'
    return 1
  }
  _gf_require_graph "$(_gf_root)" || return 1
  graphify path "$1" "$2"
}

gfexplain() {
  _gf_need graphify || return 1
  local topic="$*"
  [[ -n "$topic" ]] || {
    echo 'Usage: gfexplain "topic"'
    return 1
  }
  _gf_require_graph "$(_gf_root)" || return 1
  graphify explain "$topic"
}

# Create a compact AI context file from Graphify results.
gfai() {
  _gf_need graphify || return 1
  local q="$*"
  [[ -n "$q" ]] || {
    echo 'Usage: gfai "what should the coding agent understand?"'
    return 1
  }

  local root="$(_gf_root)"
  _gf_require_graph "$root" || return 1

  local out="$root/graphify-out/AI_CONTEXT.md"

  {
    echo "# Graphify AI Context"
    echo
    echo "- Project: $(basename "$root")"
    echo "- Source: $root"
    echo "- Generated: $(date -Iseconds)"
    echo "- Query: $q"
    echo
    echo "## Graphify Answer"
    echo
    graphify query "$q" 2>&1 || true
    echo
    echo "## Report Preview"
    echo
    sed -n '1,180p' "$root/graphify-out/GRAPH_REPORT.md" 2>/dev/null || true
  } > "$out"

  echo "Created: $out"

  if command -v wl-copy >/dev/null 2>&1; then
    cat "$out" | wl-copy
    echo "Copied to clipboard with wl-copy."
  elif command -v xclip >/dev/null 2>&1; then
    cat "$out" | xclip -selection clipboard
    echo "Copied to clipboard with xclip."
  fi
}
