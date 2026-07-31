# ============================================================
# Graphify workflow layer — code-only staging build (gfcode)
# ============================================================
# gfcode copies a pruned code/config snapshot into the staging dir
# ($GRAPHIFY_CODE_STAGE), runs Graphify there, then copies only
# graphify-out/ back into the project repo. No docs/media/secret files
# are ever staged.
# ============================================================
[[ -n ${_ZSH_TOOL_GRAPHIFY_STAGING:-} ]] && return
typeset -g _ZSH_TOOL_GRAPHIFY_STAGING=1

gfcode() {
  _gf_need graphify || return 1

  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  local project_name
  project_name="$(basename "$root")"

  local stage_root="$GRAPHIFY_CODE_STAGE"
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
