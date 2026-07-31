# ============================================================
# Graphify workflow layer — core (config, internal helpers)
# ============================================================
# Graphify: Projects -> Azkaban -> AI agents (Ubuntu/zsh).
#
# Architecture:
#   - Graphify runtime artifacts stay inside each project repo (<repo>/graphify-out/).
#   - Azkaban receives only lightweight Markdown bridge notes:
#       Cortext.md
#         <-> 04_AI_Workspace/Graphify/README.md            (generic hub)
#           <-> 04_AI_Workspace/Graphify/<slug>/metadata.md (per project)
#             <-> 05_Projects/Active/Project Graph - <name>.md
#               <-> 05_Projects/Active/Project - <name>.md
#   - Artifact copies into Azkaban happen only via explicit gfazcopy.
# ============================================================
[[ -n ${_ZSH_TOOL_GRAPHIFY_CORE:-} ]] && return
typeset -g _ZSH_TOOL_GRAPHIFY_CORE=1

# -----------------------------
# Config
# -----------------------------
export AZKABAN_DIR="${AZKABAN_DIR:-${AZKABAN_VAULT:-$HOME/azkaban}}"
export GRAPHIFY_WORKSPACE="${GRAPHIFY_WORKSPACE:-04_AI_Workspace/Graphify}"
export GRAPHIFY_DEFAULT_BACKEND="${GRAPHIFY_DEFAULT_BACKEND:-}"   # examples: ollama, claude-cli, gemini, openai
export GRAPHIFY_CODE_STAGE="${GRAPHIFY_CODE_STAGE:-${XDG_CACHE_HOME:-$HOME/.cache}/graphify-staging}"

# -----------------------------
# Internals
# -----------------------------
_gf_need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1"
    echo "Install Graphify with:"
    echo '  uv tool install "graphifyy[pdf,office,mcp,svg,sql]"'
    return 1
  }
}

_gf_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

_gf_slug() {
  local name="${1:-$(basename "$(_gf_root)")}"
  printf "%s" "$name" \
    | tr '[:upper:]' '[:lower:]' \
    | tr ' ' '-' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//'
}

_gf_abs() {
  local p="${1:-.}"
  (cd "$p" 2>/dev/null && pwd) || return 1
}

_gf_yn() {
  [[ -e "$1" ]] && echo "yes" || echo "no"
}

_gf_require_graph() {
  local root="${1:-$(_gf_root)}"
  [[ -f "$root/graphify-out/graph.json" ]] || {
    echo "No graph found at: $root/graphify-out/graph.json"
    echo "Run one of:"
    echo "  gfcode"
    echo "  gffull <backend>"
    return 1
  }
}

# -----------------------------
# Build-transaction helpers (shared by gffull/gfupdate/gfcode)
# -----------------------------

# A generated graphify-out/ is only trusted if it actually has content and
# graph.json parses as JSON. Directory-existence alone is not enough — a
# crashed/partial `graphify` run can leave an empty or truncated directory.
_gf_validate_output() {
  local dir="$1"
  if [[ ! -s "$dir/graph.json" ]]; then
    echo "Validation failed: missing or empty $dir/graph.json"
    return 1
  fi
  if ! python3 -m json.tool < "$dir/graph.json" >/dev/null 2>&1; then
    echo "Validation failed: $dir/graph.json is not valid JSON"
    return 1
  fi
  if [[ ! -s "$dir/GRAPH_REPORT.md" ]]; then
    echo "Validation failed: missing or empty $dir/GRAPH_REPORT.md"
    return 1
  fi
  return 0
}

# Fresh, private, unpredictable staging directory (mktemp -d, not a
# deterministic slug/hash path) so a local attacker can't pre-plant a
# symlink at a path staging is about to write into.
_gf_make_stage() {
  local stage_root="${GRAPHIFY_CODE_STAGE:-${XDG_CACHE_HOME:-$HOME/.cache}/graphify-staging}"
  mkdir -p -- "$stage_root" || return 1
  local stage
  stage="$(mktemp -d "$stage_root/run.XXXXXXXX")" || return 1
  chmod 700 -- "$stage" 2>/dev/null
  print -r -- "$stage"
}

# Transactional swap: validate new_dir, back up target (if present), move
# new_dir into place, drop the backup only once the move succeeded. On any
# failure the previous target is restored so a failed/interrupted build
# never destroys a previously-good graphify-out/.
_gf_install_output() {
  local new_dir="$1" target="$2"
  _gf_validate_output "$new_dir" || return 1

  local backup="${target}.backup.$$"
  if [[ -e "$target" ]]; then
    mv -- "$target" "$backup" || return 1
  fi

  if mv -- "$new_dir" "$target"; then
    rm -rf -- "$backup"
    return 0
  fi

  rm -rf -- "$target"
  [[ -e "$backup" ]] && mv -- "$backup" "$target"
  return 1
}

# Minimal YAML scalar escaper for frontmatter values interpolated from
# user-controlled project names/paths (mirrors Obsidian's _obs_yaml_escape).
_gf_yaml_escape() {
  print -rn -- "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '
}

# A project "name" ends up directly in Azkaban note filenames (e.g.
# "Project Graph - $name.md"). Reject '/' and '..' up front so a
# crafted name can't escape 05_Projects/Active/ into an arbitrary path.
_gf_validate_name() {
  local name="$1"
  if [[ "$name" == */* || "$name" == *..* ]]; then
    echo "Invalid project name (must not contain '/' or '..'): $name" >&2
    return 1
  fi
  return 0
}

# Safe managed-section updates in Markdown files.
#   _gf_md_section replace     <file> <heading> <body>
#   _gf_md_section ensure-line <file> <heading> <line>
# "replace" rewrites only the managed section (creates it at EOF if missing).
# "ensure-line" appends a line to the section once, without duplicates.
_gf_md_section() {
  python3 - "$@" <<'PY'
import re
import sys
from pathlib import Path

mode, path, heading, payload = sys.argv[1], Path(sys.argv[2]), sys.argv[3], sys.argv[4]

text = path.read_text(encoding="utf-8") if path.exists() else ""
lines = text.split("\n")

def heading_level(line):
    m = re.match(r"^(#{1,6})\s+\S", line)
    return len(m.group(1)) if m else None

sec_level = heading_level(heading) or 2

start = end = None
in_fence = False
for i, line in enumerate(lines):
    if re.match(r"^\s*(```|~~~)", line):
        in_fence = not in_fence
        continue
    if in_fence:
        continue
    if start is None:
        if line.strip() == heading:
            start = i
    else:
        level = heading_level(line)
        if level is not None and level <= sec_level:
            end = i
            break
if start is not None and end is None:
    end = len(lines)

if mode == "replace":
    body = payload.strip("\n")
elif mode == "ensure-line":
    wanted = payload.strip()
    body_lines = lines[start + 1:end] if start is not None else []
    while body_lines and not body_lines[0].strip():
        body_lines.pop(0)
    while body_lines and not body_lines[-1].strip():
        body_lines.pop()
    if not any(l.strip() == wanted for l in body_lines):
        body_lines.append(wanted)
    body = "\n".join(body_lines)
else:
    sys.exit(f"Unknown mode: {mode}")

section = [heading, ""]
if body:
    section += body.split("\n")
section.append("")

if start is None:
    head = lines[:]
    while head and not head[-1].strip():
        head.pop()
    new_lines = head + ([""] if head else []) + section
else:
    new_lines = lines[:start] + section + lines[end:]

path.parent.mkdir(parents=True, exist_ok=True)
path.write_text("\n".join(new_lines).rstrip("\n") + "\n", encoding="utf-8")
PY
}

# Ensure the generic Graphify Hub note exists. Never writes project-specific content.
_gf_ensure_hub() {
  local hub="$AZKABAN_DIR/$GRAPHIFY_WORKSPACE/README.md"
  mkdir -p "$AZKABAN_DIR/$GRAPHIFY_WORKSPACE"

  if [[ ! -f "$hub" ]]; then
    cat > "$hub" <<EOF
---
type: graphify-hub
status: active
scope: generic
---

# Graphify

Graphify is the generated project/code graph layer connected to [[Cortext]].

This note is the central hub for Graphify in the Azkaban vault.

## Core connection

- [[Cortext]]

## Purpose

Graphify generates machine-readable project graphs from codebases.

Cortext is the human-readable second-brain control layer.

This hub connects both layers without binding Graphify to any single project.

Runtime artifacts (\`graph.html\`, \`graph.json\`, \`GRAPH_REPORT.md\`) stay inside each
project repo under \`<repo>/graphify-out/\`. Azkaban holds Markdown bridge notes only.

## How projects should connect

Project-specific graph folders live under:

\`\`\`text
$GRAPHIFY_WORKSPACE/<ProjectSlug>/
\`\`\`

Each folder holds a \`metadata.md\` bridge note (and optionally \`artifacts/\` if
\`gfazcopy\` was run explicitly).

\`\`\`text
Project Note
  <-> Project Graph Note
  <-> Graphify Project Metadata
  <-> Graphify Hub
  <-> Cortext
\`\`\`

## Project graph index
EOF
    echo "Created Graphify Hub: $hub"
  else
    # Migrate the old index heading if present, so the managed section is found.
    if ! grep -qx '## Project graph index' "$hub" && grep -qx '## Future project graph index' "$hub"; then
      sed -i 's/^## Future project graph index$/## Project graph index/' "$hub"
    fi
  fi
}

# Ensure Cortext.md links only to the generic Graphify Hub, never to projects.
_gf_ensure_cortext() {
  local cortext="$AZKABAN_DIR/Cortext.md"

  if [[ ! -f "$cortext" ]]; then
    printf '# Cortext\n' > "$cortext"
    echo "Created: $cortext"
  fi

  _gf_md_section replace "$cortext" "## Graphify / Generated Project Graphs" \
    "- [[$GRAPHIFY_WORKSPACE/README|Graphify Hub]]"
}
