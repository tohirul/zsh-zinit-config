# ============================================================
# Obsidian / Azkaban — project connection & snapshots
# ============================================================
# Graph-first canonical versions. Connect/bind wire a repo to an
# existing (or new) vault note and create graph-visible links.
# Snapshots link back to the project note via a LATEST-SNAPSHOT block.
[[ -n ${_ZSH_TOOL_OBSIDIAN_PROJECTS:-} ]] && return
typeset -g _ZSH_TOOL_OBSIDIAN_PROJECTS=1

# ---------- project note resolution ----------

_obs_project_note_path() {
  local project_path="$1"
  local project_name="${2:-${project_path:t}}"
  local slug="$(_obs_slug "$project_name")"
  print -r -- "$AZKABAN_VAULT/$AZKABAN_PROJECTS_DIR/$slug.md"
}

_obs_connected_project_note() {
  local project_path="$1"
  local meta="$project_path/.azkaban/project.md"
  local rel=""

  if [[ -f "$meta" ]]; then
    rel="$(awk -F'|' '/\| Note \|/ {gsub(/^[ \t`]+|[ \t`]+$/, "", $3); print $3; exit}' "$meta")"

    if [[ -n "$rel" && -f "$AZKABAN_VAULT/$rel" ]]; then
      print -r -- "$AZKABAN_VAULT/$rel"
      return 0
    fi
  fi

  return 1
}

# ---------- connect (canonical: bind-based) ----------

obs-project-connect() {
  _obs_require_vault || return 1

  local project_path="${1:-$PWD}"
  local project_name="${2:-${project_path:t}}"

  project_path="$(realpath "$project_path" 2>/dev/null)"

  if [[ -z "$project_path" || ! -d "$project_path" ]]; then
    _obs_err "Project folder not found."
    return 1
  fi

  local slug="$(_obs_slug "$project_name")"
  local note_rel="$AZKABAN_PROJECTS_DIR/$slug.md"
  local note="$AZKABAN_VAULT/$note_rel"
  local name_esc path_esc

  name_esc="$(_obs_yaml_escape "$project_name")"
  path_esc="$(_obs_yaml_escape "$project_path")"

  mkdir -p "$AZKABAN_VAULT/$AZKABAN_PROJECTS_DIR"

  if [[ ! -f "$note" ]]; then
    cat > "$note" <<MD
---
type: project
project: "$name_esc"
slug: "$slug"
path: "$path_esc"
created: $(_obs_datetime)
status: active
tags:
  - project
  - azkaban
---

# $project_name

## Mission

Describe the purpose of this project.

MD
  fi

  obs-project-bind "$project_path" "$note_rel" "$project_name"
}

# ---------- bind (canonical) ----------

obs-project-bind() {
  _obs_require_vault || return 1

  local project_path="${1:-$PWD}"
  local note_rel="$2"
  local project_name="$3"

  project_path="$(realpath "$project_path" 2>/dev/null)"

  if [[ -z "$project_path" || ! -d "$project_path" ]]; then
    _obs_err "Project folder not found."
    _obs_info "Usage: obs-project-bind /path/to/repo \"05_Projects/Active/Existing Note.md\" \"Project Name\""
    return 1
  fi

  if [[ -z "$note_rel" ]]; then
    _obs_err "Missing vault note path."
    _obs_info "Usage: obs-project-bind /path/to/repo \"05_Projects/Active/Existing Note.md\" \"Project Name\""
    return 1
  fi

  local note="$AZKABAN_VAULT/$note_rel"

  if [[ ! -f "$note" ]]; then
    _obs_err "Vault note not found: $note_rel"
    return 1
  fi

  project_name="${project_name:-${note_rel:t:r}}"

  local meta_dir="$project_path/.azkaban"
  local meta_file="$meta_dir/project.md"
  local remote branch repo_name index index_rel note_link index_link cortext_link workflow_link
  local project_name_esc project_path_esc repo_name_esc branch_esc remote_esc

  mkdir -p "$meta_dir"

  repo_name="${project_path:t}"
  remote="$(_obs_git_remote "$project_path")"
  branch="$(_obs_git_branch "$project_path")"
  project_name_esc="$(_obs_md_table_escape "$project_name")"
  project_path_esc="$(_obs_md_table_escape "$project_path")"
  repo_name_esc="$(_obs_md_table_escape "$repo_name")"
  branch_esc="$(_obs_md_table_escape "${branch:-none}")"
  remote_esc="$(_obs_md_table_escape "${remote:-none}")"

  index="$AZKABAN_VAULT/$AZKABAN_PROJECTS_DIR/_index.md"
  index_rel="$AZKABAN_PROJECTS_DIR/_index.md"

  mkdir -p "$AZKABAN_VAULT/$AZKABAN_PROJECTS_DIR"

  if [[ ! -f "$index" ]]; then
    cat > "$index" <<MD
---
type: index
created: $(_obs_datetime)
tags:
  - index
  - projects
---

# Active Projects

MD
  fi

  note_link="$(_obs_wikilink_from_rel "$note_rel" "$project_name")"
  index_link="$(_obs_wikilink_from_rel "$index_rel" "Active Projects")"

  if [[ -f "$AZKABAN_VAULT/Cortext.md" ]]; then
    cortext_link="[[Cortext]]"
  else
    cortext_link=""
  fi

  if [[ -f "$AZKABAN_VAULT/04_AI_Workspace/Agent Workflows/Agent OS Workflow.md" ]]; then
    workflow_link="[[04_AI_Workspace/Agent Workflows/Agent OS Workflow|Agent OS Workflow]]"
  else
    workflow_link=""
  fi

  if ! grep -qF "$note_link" "$index" 2>/dev/null; then
    print -r -- "- $note_link — \`$project_path\`" >> "$index"
  fi

  cat > "$meta_file" <<MD
# Azkaban Link

This local repository is connected to an existing Obsidian project note.

| Field | Value |
|---|---|
| Project | $project_name_esc |
| Local Path | \`$project_path_esc\` |
| Vault | \`$AZKABAN_VAULT\` |
| Note | \`$note_rel\` |
| Connected | $(_obs_datetime) |

Graph node:

$note_link
MD

  {
    print -r -- ""
    print -r -- "## Repository Connection"
    print -r -- ""
    print -r -- "| Field | Value |"
    print -r -- "|---|---|"
    print -r -- "| Project | $project_name_esc |"
    print -r -- "| Local Repo | \`$project_path_esc\` |"
    print -r -- "| Repo Folder | \`$repo_name_esc\` |"
    print -r -- "| Git Branch | \`$branch_esc\` |"
    print -r -- "| Git Remote | \`$remote_esc\` |"
    print -r -- "| Connected | $(_obs_datetime) |"
    print -r -- ""
    print -r -- "## Graph Connections"
    print -r -- ""
    print -r -- "- Project index: $index_link"
    [[ -n "$cortext_link" ]] && print -r -- "- Vault home: $cortext_link"
    [[ -n "$workflow_link" ]] && print -r -- "- Agent workflow: $workflow_link"
    print -r -- ""
    print -r -- "## Current Local Repo Tasks"
    print -r -- ""
    print -r -- "- [ ] Keep this project note updated from terminal captures #task"
  } | _obs_append_or_replace_block "$note" "REPO-CONNECTION"

  _obs_ok "Bound repo to existing vault note:"
  print -r -- "  Repo: $project_path"
  print -r -- "  Note: $note_rel"
  _obs_ok "Graph-visible links updated inside the note."
}

# ---------- project log / task ----------

obs-project-log() {
  _obs_require_vault || return 1

  local message="$1"
  local project_path="${2:-$PWD}"
  local project_name="${project_path:t}"
  local note

  if [[ -z "$message" ]]; then
    _obs_err "Usage: obs-project-log \"message\" [project-path]"
    return 1
  fi

  project_path="$(realpath "$project_path" 2>/dev/null)"
  note="$(_obs_connected_project_note "$project_path" 2>/dev/null || true)"
  [[ -z "$note" ]] && note="$(_obs_project_note_path "$project_path" "$project_name")"

  if [[ ! -f "$note" ]]; then
    _obs_info "Project note not found. Connecting first..."
    obs-project-connect "$project_path" "$project_name" || return 1
    note="$(_obs_connected_project_note "$project_path" 2>/dev/null || true)"
    [[ -z "$note" ]] && note="$(_obs_project_note_path "$project_path" "$project_name")"
  fi

  cat >> "$note" <<MD

### $(_obs_datetime)

$message
MD

  _obs_ok "Logged to project note: ${note#$AZKABAN_VAULT/}"
}

obs-project-task() {
  _obs_require_vault || return 1

  local task="$1"
  local project_path="${2:-$PWD}"
  local project_name="${project_path:t}"
  local note

  if [[ -z "$task" ]]; then
    _obs_err "Usage: obs-project-task \"task\" [project-path]"
    return 1
  fi

  project_path="$(realpath "$project_path" 2>/dev/null)"
  note="$(_obs_connected_project_note "$project_path" 2>/dev/null || true)"
  [[ -z "$note" ]] && note="$(_obs_project_note_path "$project_path" "$project_name")"

  if [[ ! -f "$note" ]]; then
    obs-project-connect "$project_path" "$project_name" || return 1
    note="$(_obs_connected_project_note "$project_path" 2>/dev/null || true)"
    [[ -z "$note" ]] && note="$(_obs_project_note_path "$project_path" "$project_name")"
  fi

  cat >> "$note" <<MD

- [ ] $task #task 📥 $(_obs_date)
MD

  _obs_ok "Added task to project note: ${note#$AZKABAN_VAULT/}"
}

# ---------- snapshot (graph-first + rich sections) ----------

obs-project-snapshot() {
  _obs_require_vault || return 1

  local project_path="${1:-$PWD}"
  local project_name="${2:-${project_path:t}}"

  project_path="$(realpath "$project_path" 2>/dev/null)"

  if [[ -z "$project_path" || ! -d "$project_path" ]]; then
    _obs_err "Project folder not found."
    return 1
  fi

  local meta="$project_path/.azkaban/project.md"
  local note_rel=""

  if [[ -f "$meta" ]]; then
    note_rel="$(awk -F'|' '/\| Note \|/ {gsub(/^[ \t`]+|[ \t`]+$/, "", $3); print $3; exit}' "$meta")"
  fi

  local slug="$(_obs_slug "$project_name")"
  local dir="$AZKABAN_VAULT/$AZKABAN_PROJECTS_DIR/$slug"
  local file="$dir/snapshot-$(_obs_date)-$(date +%H%M%S-%N).md"
  local snapshot_rel="${file#$AZKABAN_VAULT/}"
  local name_esc path_esc

  name_esc="$(_obs_yaml_escape "$project_name")"
  path_esc="$(_obs_yaml_escape "$project_path")"

  mkdir -p "$dir"

  {
    print -r -- "---"
    print -r -- "type: project-snapshot"
    print -r -- "project: \"$name_esc\""
    print -r -- "path: \"$path_esc\""
    print -r -- "created: $(_obs_datetime)"
    print -r -- "tags:"
    print -r -- "  - project"
    print -r -- "  - snapshot"
    print -r -- "---"
    print -r -- ""
    print -r -- "# Snapshot — $project_name"
    print -r -- ""
    if [[ -n "$note_rel" ]]; then
      print -r -- "Project note: $(_obs_wikilink_from_rel "$note_rel" "$project_name")"
      print -r -- ""
    fi
    print -r -- "## Path"
    print -r -- ""
    print -r -- "\`$project_path\`"
    print -r -- ""
    print -r -- "## Git Status"
    print -r -- ""
    print -r -- "\`\`\`text"
    git -C "$project_path" status --short 2>/dev/null || print -r -- "Not a Git repository."
    print -r -- "\`\`\`"
    print -r -- ""
    print -r -- "## Branch"
    print -r -- ""
    print -r -- "\`\`\`text"
    git -C "$project_path" branch --show-current 2>/dev/null || true
    print -r -- "\`\`\`"
    print -r -- ""
    print -r -- "## Remote"
    print -r -- ""
    print -r -- "\`\`\`text"
    git -C "$project_path" remote -v 2>/dev/null || true
    print -r -- "\`\`\`"
    print -r -- ""
    print -r -- "## Top-Level Structure"
    print -r -- ""
    print -r -- "\`\`\`text"
    find "$project_path" -maxdepth 2 \
      -not -path '*/.git/*' \
      -not -path '*/node_modules/*' \
      -not -path '*/.next/*' \
      -not -path '*/dist/*' \
      -not -path '*/build/*' \
      -print 2>/dev/null \
      | sed "s|$project_path|.|" \
      | sort \
      | head -200
    print -r -- "\`\`\`"

    if [[ -f "$project_path/package.json" ]]; then
      print -r -- ""
      print -r -- "## package.json Scripts"
      print -r -- ""
      print -r -- "\`\`\`json"
      python3 - "$project_path/package.json" <<'PY' 2>/dev/null
import json, sys
p = sys.argv[1]
with open(p, "r", encoding="utf-8") as f:
    data = json.load(f)
print(json.dumps(data.get("scripts", {}), indent=2))
PY
      print -r -- "\`\`\`"
    fi

    if [[ -f "$project_path/docker-compose.yml" || -f "$project_path/compose.yml" ]]; then
      print -r -- ""
      print -r -- "## Docker Compose"
      print -r -- ""
      print -r -- "- Found: \`docker-compose.yml\` or \`compose.yml\`"
    fi

    if [[ -f "$project_path/README.md" ]]; then
      print -r -- ""
      print -r -- "## README Preview"
      print -r -- ""
      print -r -- "\`\`\`md"
      sed -n '1,120p' "$project_path/README.md"
      print -r -- "\`\`\`"
    fi
  } > "$file"

  if [[ -n "$note_rel" && -f "$AZKABAN_VAULT/$note_rel" ]]; then
    {
      print -r -- ""
      print -r -- "## Latest Snapshot"
      print -r -- ""
      print -r -- "- $(_obs_wikilink_from_rel "$snapshot_rel" "Snapshot $(_obs_date) $(date +%H:%M)")"
    } | _obs_append_or_replace_block "$AZKABAN_VAULT/$note_rel" "LATEST-SNAPSHOT"
  fi

  _obs_ok "Created graph-linked snapshot:"
  print -r -- "  $snapshot_rel"
}

# ---------- project listing ----------

obs-projects() {
  _obs_require_vault || return 1

  local dir="$AZKABAN_VAULT/$AZKABAN_PROJECTS_DIR"

  if [[ ! -d "$dir" ]]; then
    _obs_err "No Projects directory found in vault."
    return 1
  fi

  find "$dir" -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sort
}

# ---------- current-dir conveniences ----------

obs-connect-current() {
  local project_name="${PWD:t}"

  if [[ "$PWD" == "$HOME/.zsh" ]]; then
    project_name="Zsh Configuration"
  fi

  obs-project-connect "$PWD" "$project_name"
}

obs-log-current() {
  local message="$*"

  if [[ -z "$message" ]]; then
    _obs_err "Usage: obs-log-current \"message\""
    return 1
  fi

  obs-project-log "$message" "$PWD"
}

obs-task-current() {
  local task="$*"

  if [[ -z "$task" ]]; then
    _obs_err "Usage: obs-task-current \"task\""
    return 1
  fi

  obs-project-task "$task" "$PWD"
}

obs-snapshot-current() {
  obs-project-snapshot "$PWD" "${PWD:t}"
}

# ---------- graph info ----------

obs-graph-info() {
  _obs_require_vault || return 1

  print -r -- "Graph changes are created by markdown links like:"
  print -r -- ""
  print -r -- "  [[05_Projects/Active/Project - BanglarBike Next.js Migration|BanglarBike Next.js Migration]]"
  print -r -- "  [[05_Projects/Active/_index|Active Projects]]"
  print -r -- "  [[Cortext]]"
  print -r -- "  [[04_AI_Workspace/Agent Workflows/Agent OS Workflow|Agent OS Workflow]]"
  print -r -- ""
  print -r -- "Open Obsidian Graph View manually and watch these nodes connect."
  print -r -- "This script will not open project notes unless AZKABAN_AUTO_OPEN=1."
}
