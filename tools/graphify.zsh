# ~/.zsh/tools/graphify.zsh
# Graphify workflow layer for Projects -> Azkaban -> AI agents
# Designed for Ubuntu/zsh, terminal-first project work.
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

# -----------------------------
# Config
# -----------------------------
export AZKABAN_DIR="${AZKABAN_DIR:-$HOME/azkaban}"
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

# -----------------------------
# Install / setup helpers
# -----------------------------
gfinstall() {
  if ! command -v uv >/dev/null 2>&1; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi

  uv tool install -U "graphifyy[pdf,office,mcp,svg,sql]"
  uv tool update-shell
  echo "Graphify installed. Restart terminal or run:"
  echo '  export PATH="$HOME/.local/bin:$PATH"'
  graphify --version 2>/dev/null || true
}

gfinitignore() {
  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  cd "$root" || return 1

  [[ -f .graphifyignore ]] && cp .graphifyignore ".graphifyignore.bak.$(date +%Y%m%d-%H%M%S)"

  cat > .graphifyignore <<'EOF'
# Graphify ignores
.git/
node_modules/
**/node_modules/
.next/
**/.next/
dist/
build/
coverage/
.cache/
.turbo/
.DS_Store

# Graphify runtime
graphify-out/
.graphify-code-only/

# Secrets / local env
.env
.env.*
**/.env
**/.env.*
**/*secret*
**/*token*
**/*.key
**/*.pem

# Heavy/generated files
**/*.zip
**/*.tar
**/*.tar.gz
**/*.7z
**/*.log
EOF

  grep -qxF 'graphify-out/' .gitignore 2>/dev/null || cat >> .gitignore <<'EOF'

# Graphify local outputs
graphify-out/
.graphify-code-only/
EOF

  echo "Created: $root/.graphifyignore"
  echo "Updated: $root/.gitignore"
}

# -----------------------------
# Build graphs
# -----------------------------
gfcode() {
  _gf_need graphify || return 1

  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  local project_name
  project_name="$(basename "$root")"

  local stage_root="${XDG_CACHE_HOME:-$HOME/.cache}/graphify-staging"
  local root_hash
  root_hash="$(printf '%s' "$root" | sha1sum | awk '{print substr($1,1,8)}')"

  local stage="$stage_root/$(_gf_slug "$project_name")-$root_hash-code-only"

  cd "$root" || return 1

  echo "Building Graphify code-only graph:"
  echo "  Project: $root"
  echo "  Stage:   $stage"

  rm -rf "$stage" "$root/graphify-out"
  mkdir -p "$stage"

  python3 - "$root" "$stage" <<'PY2'
from pathlib import Path
import os
import shutil
import sys
from collections import Counter

root = Path(sys.argv[1]).resolve()
stage = Path(sys.argv[2]).resolve()

blocked_dir_names = {
    ".git",
    ".svn",
    ".hg",
    "node_modules",
    ".next",
    "dist",
    "build",
    "coverage",
    ".turbo",
    ".cache",
    ".venv",
    "venv",
    "__pycache__",
    "vendor",
    "storage",
    "bootstrap",
    "graphify-out",
    ".graphify-code-only",
}

allowed_suffixes = {
    ".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".mts", ".cts",
    ".json", ".sql", ".prisma",
    ".css", ".scss", ".sass",
    ".sh", ".bash", ".zsh",
    ".toml", ".ini",
    ".php", ".py",
}

allowed_names = {
    "Dockerfile",
    "package.json",
    "package-lock.json",
    "pnpm-lock.yaml",
    "yarn.lock",
    "tsconfig.json",
    "jsconfig.json",
    "next.config.js",
    "next.config.mjs",
    "next.config.ts",
    "vite.config.js",
    "vite.config.ts",
    "tailwind.config.js",
    "tailwind.config.ts",
    "postcss.config.js",
    "postcss.config.mjs",
    "composer.json",
    "composer.lock",
    "artisan",
}

blocked_suffixes = {
    ".md", ".mdx", ".txt", ".rst",
    ".pdf", ".doc", ".docx", ".ppt", ".pptx",
    ".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".ico",
    ".html", ".htm",
    ".zip", ".tar", ".gz", ".7z", ".rar",
    ".log",
}

def is_blocked_file(path: Path) -> bool:
    name = path.name.lower()

    if name.startswith(".env"):
        return True

    if "secret" in name or "token" in name:
        return True

    if name.endswith(".pem") or name.endswith(".key"):
        return True

    if path.suffix.lower() in blocked_suffixes:
        return True

    return False

def is_allowed_file(path: Path) -> bool:
    name = path.name

    if name.endswith(".blade.php"):
        return True

    if name in allowed_names:
        return True

    return path.suffix.lower() in allowed_suffixes

copied = 0
top_counts = Counter()

for current_root, dirs, files in os.walk(root):
    current_path = Path(current_root)

    # prune blocked dirs before walking deeper
    dirs[:] = [d for d in dirs if d not in blocked_dir_names]

    for filename in files:
        src = current_path / filename

        if is_blocked_file(src):
            continue

        if not is_allowed_file(src):
            continue

        rel = src.relative_to(root)
        dest = stage / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)

        copied += 1
        top_counts[rel.parts[0]] += 1

print(f"Copied code/config files into staging: {copied}")

if copied:
    print("Top copied folders:")
    for name, count in top_counts.most_common(20):
        print(f"  {name}: {count}")

if copied == 0:
    print("ERROR: copied 0 files. Check repo structure or allowed extensions.", file=sys.stderr)
    sys.exit(2)
PY2

  echo
  echo "Sanity checks:"
  echo -n "  Total staged files: "
  find "$stage" -type f | wc -l

  echo -n "  node_modules files: "
  find "$stage" -path "*/node_modules/*" -type f | wc -l

  echo -n "  docs/media files: "
  find "$stage" -type f | grep -Ei '\.(md|mdx|txt|rst|pdf|docx?|pptx?|png|jpe?g|webp|gif|svg|ico|html?)$' | wc -l

  local bad_node_modules
  bad_node_modules="$(find "$stage" -path "*/node_modules/*" -type f | sed -n '1,20p')"

  if [[ -n "$bad_node_modules" ]]; then
    echo
    echo "Blocked: node_modules slipped into staging:"
    echo "$bad_node_modules"
    return 1
  fi

  local leaked
  leaked="$(find "$stage" -type f | grep -Ei '\.(md|mdx|txt|rst|pdf|docx?|pptx?|png|jpe?g|webp|gif|svg|ico|html?)$' || true)"

  if [[ -n "$leaked" ]]; then
    echo
    echo "Blocked: semantic docs/media slipped into staging:"
    echo "$leaked"
    return 1
  fi

  local count
  count="$(find "$stage" -type f | wc -l)"

  if [[ "$count" -eq 0 ]]; then
    echo
    echo "Blocked: staging folder has 0 files."
    return 1
  fi

  echo
  echo "Staging preview:"
  find "$stage" -type f | sed -n '1,60p'

  echo
  echo "Running Graphify from external staging folder..."

  (
    cd "$stage" || exit 1

    cat > .graphifyignore <<'EOF2'
.git/
node_modules/
.next/
dist/
build/
coverage/
vendor/
storage/
bootstrap/cache/
graphify-out/
.env
.env.*
*.md
*.mdx
*.txt
*.rst
*.pdf
*.doc
*.docx
*.ppt
*.pptx
*.png
*.jpg
*.jpeg
*.webp
*.gif
*.svg
*.ico
*.html
*.htm
*.yml
*.yaml
EOF2

    graphify . --wiki --svg --force || exit 1

    echo
    echo "Running Graphify cluster/report generation..."
    graphify cluster-only . || exit 1
  ) || return 1

  if [[ ! -d "$stage/graphify-out" ]]; then
    echo
    echo "Graphify did not create output:"
    echo "  $stage/graphify-out"
    return 1
  fi

  rm -rf "$root/graphify-out"
  cp -a "$stage/graphify-out" "$root/graphify-out"

  echo
  echo "Done:"
  echo "  $root/graphify-out/graph.html"
  echo "  $root/graphify-out/GRAPH_REPORT.md"
  echo "  $root/graphify-out/graph.json"
}

gffull() {
  _gf_need graphify || return 1

  local backend="${1:-$GRAPHIFY_DEFAULT_BACKEND}"
  local root="$(_gf_abs "${2:-$(_gf_root)}")" || return 1
  cd "$root" || return 1

  echo "Building Graphify full graph:"
  echo "  Project: $root"
  [[ -n "$backend" ]] && echo "  Backend: $backend"

  rm -rf graphify-out

  if [[ -n "$backend" ]]; then
    graphify . --wiki --svg --backend "$backend" --force
  else
    graphify . --wiki --svg --force
  fi
}

gfupdate() {
  _gf_need graphify || return 1
  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  cd "$root" || return 1
  graphify . --update
}

# -----------------------------
# Open / inspect / query
# -----------------------------
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

# -----------------------------
# Azkaban bridge notes (Markdown only, no artifact copies)
# -----------------------------
# gfaz "Project Name" ["/path/to/project-note.md"]
# Creates/updates only Markdown bridge notes in Azkaban. Runtime artifacts
# stay in <repo>/graphify-out. Use gfazcopy for an explicit artifact copy.
gfaz() {
  local name="${1:-$(basename "$(_gf_root)")}"
  local explicit_note="${2:-}"
  local root="$(_gf_abs "$(_gf_root)")" || return 1
  local slug="$(_gf_slug "$name")"

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
project: $name
source_repo: $root
generated_graph_runtime: $root/graphify-out
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
project: $name
source_repo: $root
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

# -----------------------------
# Hooks / assistant installers
# -----------------------------
gfhook() {
  _gf_need graphify || return 1
  local action="${1:-status}"
  case "$action" in
    install|uninstall|status)
      graphify hook "$action"
      ;;
    *)
      echo "Usage: gfhook install|uninstall|status"
      return 1
      ;;
  esac
}

gfagents() {
  _gf_need graphify || return 1

  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  cd "$root" || return 1

  echo "Installing Graphify assistant instructions in:"
  echo "  $root"

  graphify claude install 2>/dev/null || graphify install --project 2>/dev/null || true
  graphify codex install 2>/dev/null || graphify install --platform codex --project 2>/dev/null || true
  graphify opencode install 2>/dev/null || graphify install --platform opencode --project 2>/dev/null || true

  echo "Check changes:"
  echo "  git status --short"
}

# -----------------------------
# Status / help
# -----------------------------
gfstatus() {
  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1

  echo "Graphify workflow status"
  echo "------------------------"
  echo "Project:              $root"
  echo "Azkaban:              $AZKABAN_DIR"
  echo "Azkaban graph folder: $AZKABAN_DIR/$GRAPHIFY_WORKSPACE"
  echo "Default backend:      ${GRAPHIFY_DEFAULT_BACKEND:-none}"
  echo

  if command -v graphify >/dev/null 2>&1; then
    echo -n "Graphify:             "
    graphify --version 2>/dev/null || echo "installed"
  else
    echo "Graphify:             missing"
  fi

  [[ -f "$root/graphify-out/graph.json" ]] && echo "Project graph:        yes" || echo "Project graph:        no"
  [[ -f "$root/graphify-out/GRAPH_REPORT.md" ]] && echo "Project report:       yes" || echo "Project report:       no"
}

gfhelp() {
  cat <<'EOF'
Graphify zsh workflow

Runtime artifacts stay in <repo>/graphify-out.
Azkaban receives Markdown bridge notes only (Cortext <-> Hub <-> metadata <-> notes).

Install:
  gfinstall

Project setup:
  gfinitignore                    # create .graphifyignore + gitignore entries

Build:
  gfcode                          # build project-side graphify-out (code-only, offline)
  gffull <backend>                # full graph with backend: ollama, claude-cli, gemini, openai...
  gfupdate                        # update existing graph

Inspect:
  gfopen                          # open project-side graph.html
  gfreport                        # read project-side GRAPH_REPORT.md
  gfjson                          # inspect project-side graph.json
  gfstatus                        # show workflow status

Query:
  gfq "question"                  # query project-side graph
  gfpath "node A" "node B"
  gfexplain "topic"
  gfai "question for an AI coding agent"

Azkaban bridge:
  gfaz "Project Name"             # create/update Azkaban Markdown bridge notes only
  gfaz "Project Name" "/note.md"  # same, with explicit project note path
  gfazcopy "Project Name"         # optional: copy artifacts into Azkaban artifacts folder
  gfazstatus "Project Name"       # inspect project/Azkaban bridge state
  gfship "Project Name"           # gfcode + gfaz + gfopen (no artifact copy)
  gfobsidian "Project Name"       # full Obsidian export into Azkaban (not default)

Hooks / agents:
  gfhook install|status|uninstall
  gfagents                        # install Graphify agent instructions where supported
EOF
}

# Short aliases
alias gfs='gfstatus'
alias gfi='gfinitignore'
alias gfc='gfcode'
alias gff='gffull'
alias gfu='gfupdate'
alias gfo='gfopen'
alias gfr='gfreport'
alias gfj='gfjson'
alias gfa='gfaz'
alias gfsh='gfship'
alias gfoz='gfobsidian'
