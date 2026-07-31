# ============================================================
# Graphify workflow layer — code-only staging build (gfcode)
# ============================================================
# gfcode copies a pruned code/config snapshot into a fresh, private
# staging dir (mktemp under $GRAPHIFY_CODE_STAGE), runs Graphify there,
# then transactionally installs graphify-out/ back into the project
# repo. No docs/media/secret files are ever staged. The staging dir is
# always removed on success, failure, or interruption unless
# GRAPHIFY_KEEP_STAGE=1.
# ============================================================
[[ -n ${_ZSH_TOOL_GRAPHIFY_STAGING:-} ]] && return
typeset -g _ZSH_TOOL_GRAPHIFY_STAGING=1

gfcode() {
  _gf_need graphify || return 1

  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1
  local project_name
  project_name="$(basename "$root")"

  cd "$root" || return 1

  echo "Building Graphify code-only graph:"
  echo "  Project: $root"

  (
    local stage
    stage="$(_gf_make_stage)" || { echo "Failed to create staging directory."; exit 1; }

    trap '
      if [[ "${GRAPHIFY_KEEP_STAGE:-0}" != 1 ]]; then
        rm -rf -- "$stage"
      else
        print -r -- "Retained stage: $stage"
      fi
    ' EXIT INT TERM HUP

    echo "  Stage:   $stage"

    GRAPHIFY_MAX_FILE_SIZE="${GRAPHIFY_MAX_FILE_SIZE:-2097152}" \
    python3 - "$root" "$stage" <<'PY2'
from pathlib import Path
import json
import os
import shutil
import sys
from collections import Counter

root = Path(sys.argv[1]).resolve()
stage = Path(sys.argv[2]).resolve()
max_size = int(os.environ.get("GRAPHIFY_MAX_FILE_SIZE", 2 * 1024 * 1024))

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

    if "secret" in name or "token" in name or "credentials" in name:
        return True

    if name.startswith("id_rsa") or name.startswith("id_ed25519"):
        return True

    if name.endswith((".pem", ".key", ".p12", ".pfx")):
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
excluded = Counter()
total_bytes = 0

for current_root, dirs, files in os.walk(root):
    current_path = Path(current_root)

    # prune blocked dirs before walking deeper
    dirs[:] = [d for d in dirs if d not in blocked_dir_names]

    for filename in files:
        src = current_path / filename

        if is_blocked_file(src):
            excluded["blocklisted"] += 1
            continue

        if not is_allowed_file(src):
            excluded["not-allowed-extension"] += 1
            continue

        # Security containment, independent of the name-based policy above:
        if src.is_symlink():
            excluded["symlink"] += 1
            continue

        try:
            resolved = src.resolve(strict=True)
        except OSError:
            excluded["unresolvable"] += 1
            continue

        try:
            resolved.relative_to(root)
        except ValueError:
            excluded["outside-root"] += 1
            continue

        if not resolved.is_file():
            excluded["not-regular-file"] += 1
            continue

        try:
            size = resolved.stat().st_size
        except OSError:
            excluded["stat-failed"] += 1
            continue

        if size > max_size:
            excluded["too-large"] += 1
            continue

        rel = src.relative_to(root)
        dest = stage / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(resolved, dest, follow_symlinks=False)

        copied += 1
        total_bytes += size
        top_counts[rel.parts[0]] += 1

print(f"Copied code/config files into staging: {copied}")

if copied:
    print("Top copied folders:")
    for name, count in top_counts.most_common(20):
        print(f"  {name}: {count}")

if excluded:
    print("Excluded:")
    for reason, count in sorted(excluded.items()):
        print(f"  {reason}: {count}")

manifest = {
    "policy_version": 1,
    "project_root": str(root),
    "stage": str(stage),
    "copied": copied,
    "total_bytes": total_bytes,
    "excluded": dict(excluded),
    "max_file_size": max_size,
}
(stage / "graphify-stage-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

if copied == 0:
    print("ERROR: copied 0 files. Check repo structure or allowed extensions.", file=sys.stderr)
    sys.exit(2)
PY2
    local stage_rc=$?
    (( stage_rc == 0 )) || exit 1

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
      exit 1
    fi

    local leaked
    leaked="$(find "$stage" -type f | grep -Ei '\.(md|mdx|txt|rst|pdf|docx?|pptx?|png|jpe?g|webp|gif|svg|ico|html?)$' || true)"

    if [[ -n "$leaked" ]]; then
      echo
      echo "Blocked: semantic docs/media slipped into staging:"
      echo "$leaked"
      exit 1
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
**/*secret*
**/*token*
**/*credentials*
*.pem
*.key
*.p12
*.pfx
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
    ) || exit 1

    if ! _gf_validate_output "$stage/graphify-out"; then
      exit 1
    fi

    if ! _gf_install_output "$stage/graphify-out" "$root/graphify-out"; then
      echo "Failed to install graphify-out (previous output, if any, was restored)."
      exit 1
    fi

    echo
    echo "Done:"
    echo "  $root/graphify-out/graph.html"
    echo "  $root/graphify-out/GRAPH_REPORT.md"
    echo "  $root/graphify-out/graph.json"
  ) || return 1
}
