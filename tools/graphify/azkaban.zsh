# ============================================================
# Graphify workflow layer — Azkaban bridge notes
# ============================================================
# gfaz "Project Name" ["/path/to/project-note.md"]
# Creates/updates only Markdown bridge notes in Azkaban. Runtime artifacts
# stay in <repo>/graphify-out. Use gfazcopy for an explicit artifact copy.
# ============================================================
[[ -n ${_ZSH_TOOL_GRAPHIFY_AZKABAN:-} ]] && return
typeset -g _ZSH_TOOL_GRAPHIFY_AZKABAN=1

gfaz() {
  local name="${1:-$(basename "$(_gf_root)")}"
  local explicit_note="${2:-}"
  _gf_validate_name "$name" || return 1
  local root="$(_gf_abs "$(_gf_root)")" || return 1
  local slug="$(_gf_slug "$name")"
  local name_esc="$(_gf_yaml_escape "$name")"
  local root_esc="$(_gf_yaml_escape "$root")"

  local hub_rel="$GRAPHIFY_WORKSPACE/README"
  local meta_rel="$GRAPHIFY_WORKSPACE/$slug/metadata"
  local meta_note="$AZKABAN_DIR/$GRAPHIFY_WORKSPACE/$slug/metadata.md"
  local graph_note_dir="$AZKABAN_DIR/05_Projects/Active"
  local graph_note="$graph_note_dir/Project Graph - $name.md"
  local project_note="$graph_note_dir/Project - $name.md"
  local stamp="$(date -Iseconds)"

  _gf_require_graph "$root" || return 1

  if [[ -n "$explicit_note" && ! -f "$explicit_note" ]]; then
    echo "Explicit project note not found: $explicit_note"
    return 1
  fi

  mkdir -p "$AZKABAN_DIR/$GRAPHIFY_WORKSPACE/$slug" "$graph_note_dir"

  _gf_ensure_hub
  _gf_ensure_cortext

  # Project metadata note (Graphify Hub <-> project bridge)
  cat > "$meta_note" <<EOF
---
type: graphify-project
project: "$name_esc"
source_repo: "$root_esc"
generated_graph_runtime: "$root_esc/graphify-out"
status: active
updated: $stamp
---

# $name Graphify Metadata

This note connects the project-specific generated Graphify graph to the generic [[$hub_rel|Graphify Hub]].

## Core links

- [[$hub_rel|Graphify Hub]]
- [[05_Projects/Active/Project Graph - $name|Project Graph - $name]]
- [[05_Projects/Active/Project - $name|Project - $name]]

## Runtime artifacts

Runtime artifacts stay in the project repo, not in Azkaban:

\`\`\`bash
cd "$root"
ls graphify-out
gfopen
gfreport
gfq "summarize the architecture"
\`\`\`

Expected project-side files:

- \`graphify-out/graph.html\`
- \`graphify-out/graph.json\`
- \`graphify-out/GRAPH_REPORT.md\`

## Agent questions

\`\`\`bash
cd "$root"

gfq "summarize the architecture"
gfq "which files are central to routing?"
gfq "which modules are risky to change?"
gfpath "frontend" "backend"
gfexplain "authentication"
\`\`\`
EOF

  # Project Graph note (human project note <-> generated graph bridge)
  cat > "$graph_note" <<EOF
---
type: graphify-index
project: "$name_esc"
source_repo: "$root_esc"
graphify_metadata: $meta_rel
status: active
updated: $stamp
---

# Project Graph - $name

This note bridges the human project note and the generated Graphify code graph.

## Core links

- [[$hub_rel|Graphify Hub]]
- [[$meta_rel|$name Graphify Metadata]]
- [[05_Projects/Active/Project - $name|Project - $name]]

## Runtime source

\`\`\`bash
cd "$root"

gfopen
gfreport
gfq "summarize the architecture"
gfq "which modules are risky to change?"
gfpath "frontend" "backend"
gfexplain "authentication"
\`\`\`

## Purpose

Graphify gives machine-readable code structure.

The project note gives human-readable project memory.

This note connects both.
EOF

  # Index this project in the generic hub, once.
  _gf_md_section ensure-line "$AZKABAN_DIR/$GRAPHIFY_WORKSPACE/README.md" \
    "## Project graph index" \
    "- [[$meta_rel|$slug]]"

  # Project note: update managed section if the note exists, never create it.
  local target_note="${explicit_note:-$project_note}"
  local section_body="- [[$hub_rel|Graphify Hub]]
- [[$meta_rel|$name Graphify Metadata]]
- [[05_Projects/Active/Project Graph - $name|Project Graph - $name]]"

  if [[ -f "$target_note" ]]; then
    _gf_md_section replace "$target_note" "## Generated Graph Layer" "$section_body"
    echo "Updated project note section: $target_note"
  else
    echo "Project note not found:"
    echo "  $target_note"
    echo "Create it manually or pass explicit note path:"
    echo "  gfaz \"$name\" \"/path/to/project-note.md\""
  fi

  echo
  echo "Azkaban bridge notes updated (Markdown only, no artifacts copied):"
  echo "  $meta_note"
  echo "  $graph_note"
  echo "  $AZKABAN_DIR/$GRAPHIFY_WORKSPACE/README.md"
  echo "  $AZKABAN_DIR/Cortext.md"
}

# gfazcopy "Project Name" [repo-path]
# Optional, explicit artifact copy into Azkaban. Never runs from gfaz/gfship.
gfazcopy() {
  local name="${1:-$(basename "$(_gf_root)")}"
  _gf_validate_name "$name" || return 1
  local root="$(_gf_abs "${2:-$(_gf_root)}")" || return 1
  local slug="$(_gf_slug "$name")"
  local dest="$AZKABAN_DIR/$GRAPHIFY_WORKSPACE/$slug/artifacts"

  _gf_require_graph "$root" || return 1

  mkdir -p "$dest"

  local copied=0
  local f
  for f in graph.html graph.json GRAPH_REPORT.md graph.svg AI_CONTEXT.md; do
    if [[ -f "$root/graphify-out/$f" ]]; then
      cp -f "$root/graphify-out/$f" "$dest/$f"
      echo "Copied: $f"
      copied=$((copied + 1))
    fi
  done

  if [[ "$copied" -eq 0 ]]; then
    echo "Nothing copied from: $root/graphify-out"
    return 1
  fi

  echo
  echo "Artifacts copied into:"
  echo "  $dest"
}

# gfazstatus "Project Name"
# Inspect project/Azkaban bridge state.
gfazstatus() {
  local name="${1:-$(basename "$(_gf_root)")}"
  _gf_validate_name "$name" || return 1
  local root="$(_gf_abs "$(_gf_root)")" || return 1
  local slug="$(_gf_slug "$name")"

  local hub="$AZKABAN_DIR/$GRAPHIFY_WORKSPACE/README.md"
  local meta_note="$AZKABAN_DIR/$GRAPHIFY_WORKSPACE/$slug/metadata.md"
  local graph_note="$AZKABAN_DIR/05_Projects/Active/Project Graph - $name.md"
  local project_note="$AZKABAN_DIR/05_Projects/Active/Project - $name.md"

  echo "Graphify bridge status: $name"
  echo "--------------------------------"
  echo "Project repo:          $root"
  echo "graphify-out:          $(_gf_yn "$root/graphify-out")"
  echo "graph.json:            $(_gf_yn "$root/graphify-out/graph.json")"
  echo "graph.html:            $(_gf_yn "$root/graphify-out/graph.html")"
  echo "GRAPH_REPORT.md:       $(_gf_yn "$root/graphify-out/GRAPH_REPORT.md")"
  echo
  echo "Azkaban Graphify hub:  $(_gf_yn "$hub")"
  echo "  $hub"
  echo "Metadata note:         $(_gf_yn "$meta_note")"
  echo "  $meta_note"
  echo "Project graph note:    $(_gf_yn "$graph_note")"
  echo "  $graph_note"
  echo "Project note:          $(_gf_yn "$project_note")"
  echo "  $project_note"
}

# Build code-only graph, create Azkaban bridge notes, open result.
# Does NOT copy artifacts into Azkaban (use gfazcopy explicitly for that).
gfship() {
  local name="${1:-$(basename "$(_gf_root)")}"
  _gf_validate_name "$name" || return 1
  local root="$(_gf_abs "${2:-$(_gf_root)}")" || return 1

  gfcode "$root" || return 1
  ( cd "$root" && gfaz "$name" ) || return 1
  gfopen "$root"
}

# Full Obsidian export directly into Azkaban. NOT the default workflow —
# prefer gfaz (bridge notes only). Use only with a backend if the repo
# contains docs/images/PDFs.
gfobsidian() {
  _gf_need graphify || return 1

  local name="${1:-$(basename "$(_gf_root)")}"
  _gf_validate_name "$name" || return 1
  local backend="${2:-$GRAPHIFY_DEFAULT_BACKEND}"
  local root="$(_gf_abs "${3:-$(_gf_root)}")" || return 1
  local slug="$(_gf_slug "$name")"
  local dest="$AZKABAN_DIR/$GRAPHIFY_WORKSPACE/$slug/obsidian"

  mkdir -p "$dest"
  cd "$root" || return 1

  if [[ -n "$backend" ]]; then
    graphify . --obsidian --obsidian-dir "$dest" --wiki --svg --backend "$backend" --force
  else
    graphify . --obsidian --obsidian-dir "$dest" --wiki --svg --force
  fi

  echo "Obsidian export (full, non-default):"
  echo "  $dest"
}
