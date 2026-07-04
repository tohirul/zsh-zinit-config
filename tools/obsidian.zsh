# ~/.zsh/tools/obsidian.zsh
# Obsidian / Azkaban automation helpers
# Vault default: ~/azkaban
[[ -n ${_ZSH_TOOL_OBSIDIAN:-} ]] && return
typeset -g _ZSH_TOOL_OBSIDIAN=1

export AZKABAN_VAULT="${AZKABAN_VAULT:-$HOME/azkaban}"
export AZKABAN_PROJECTS_DIR="${AZKABAN_PROJECTS_DIR:-05_Projects/Active}"
export OBSIDIAN_VAULT_NAME="${OBSIDIAN_VAULT_NAME:-$(basename "$AZKABAN_VAULT")}"

# ---------- internal helpers ----------

_obs_err() {
  print -P "%F{red}✘%f $*" >&2
}

_obs_ok() {
  print -P "%F{green}✓%f $*"
}

_obs_info() {
  print -P "%F{cyan}›%f $*"
}

_obs_require_vault() {
  if [[ ! -d "$AZKABAN_VAULT" ]]; then
    _obs_err "Azkaban vault not found: $AZKABAN_VAULT"
    _obs_info "Set it with: export AZKABAN_VAULT=~/azkaban"
    return 1
  fi
}

_obs_slug() {
  local input="$*"
  input="${input:t}"
  print -r -- "$input" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^[._-]+//; s/[._-]+$//'
}

_obs_title() {
  local input="$*"
  input="${input:t}"
  print -r -- "$input" | sed -E 's/[-_]+/ /g; s/\b(.)/\u\1/g'
}

_obs_date() {
  date +"%Y-%m-%d"
}

_obs_time() {
  date +"%H:%M"
}

_obs_datetime() {
  date +"%Y-%m-%d %H:%M:%S"
}

_obs_urlencode() {
  python3 - "$1" <<'PY'
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
}

_obs_open_file() {
  local file="$1"
  local rel="${file#$AZKABAN_VAULT/}"
  local encoded_vault encoded_file

  encoded_vault="$(_obs_urlencode "$OBSIDIAN_VAULT_NAME")"
  encoded_file="$(_obs_urlencode "$rel")"

  xdg-open "obsidian://open?vault=${encoded_vault}&file=${encoded_file}" >/dev/null 2>&1 &
}

_obs_git_remote() {
  git -C "$1" remote get-url origin 2>/dev/null || true
}

_obs_git_branch() {
  git -C "$1" branch --show-current 2>/dev/null || true
}

_obs_git_status_short() {
  git -C "$1" status --short 2>/dev/null || true
}

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
    rel="$(awk -F'|' '/\| Note \|/ {gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3; exit}' "$meta")"

    if [[ -n "$rel" && -f "$AZKABAN_VAULT/$rel" ]]; then
      print -r -- "$AZKABAN_VAULT/$rel"
      return 0
    fi
  fi

  return 1
}

# ---------- vault actions ----------

obs-home() {
  _obs_require_vault || return 1
  xdg-open "$AZKABAN_VAULT" >/dev/null 2>&1 &
  _obs_ok "Opened vault folder: $AZKABAN_VAULT"
}

obs-open() {
  _obs_require_vault || return 1

  local target="$1"

  if [[ -z "$target" ]]; then
    xdg-open "obsidian://open?vault=$(_obs_urlencode "$OBSIDIAN_VAULT_NAME")" >/dev/null 2>&1 &
    _obs_ok "Opened Obsidian vault: $OBSIDIAN_VAULT_NAME"
    return 0
  fi

  local file="$AZKABAN_VAULT/$target"

  if [[ ! -f "$file" ]]; then
    _obs_err "Note not found: $file"
    return 1
  fi

  _obs_open_file "$file"
  _obs_ok "Opened note: $target"
}

obs-today() {
  _obs_require_vault || return 1

  local dir="$AZKABAN_VAULT/Daily"
  local file="$dir/$(_obs_date).md"

  mkdir -p "$dir"

  if [[ ! -f "$file" ]]; then
    cat > "$file" <<MD
---
type: daily
date: $(_obs_date)
created: $(_obs_datetime)
tags:
  - daily
---

# $(_obs_date)

## Focus

- 

## Tasks

- [ ] 

## Notes



## Dev Log



## Captures


MD
    _obs_ok "Created daily note: Daily/$(_obs_date).md"
  else
    _obs_info "Daily note already exists: Daily/$(_obs_date).md"
  fi

  _obs_open_file "$file"
}

obs-capture() {
  _obs_require_vault || return 1

  local text="$*"

  if [[ -z "$text" ]]; then
    _obs_err "Usage: obs-capture \"your note\""
    return 1
  fi

  local dir="$AZKABAN_VAULT/Inbox"
  local file="$dir/inbox.md"

  mkdir -p "$dir"
  touch "$file"

  cat >> "$file" <<MD

- $(_obs_datetime) — $text
MD

  _obs_ok "Captured to Inbox/inbox.md"
}

obs-task() {
  _obs_require_vault || return 1

  local task="$1"
  local project="$2"

  if [[ -z "$task" ]]; then
    _obs_err "Usage: obs-task \"task text\" [project-name]"
    return 1
  fi

  local dir="$AZKABAN_VAULT/Tasks"
  local file="$dir/inbox.md"

  mkdir -p "$dir"
  touch "$file"

  if [[ -n "$project" ]]; then
    print -r -- "- [ ] $task #task #project/[[$project]] 📥 $(_obs_date)" >> "$file"
  else
    print -r -- "- [ ] $task #task 📥 $(_obs_date)" >> "$file"
  fi

  _obs_ok "Task added to Tasks/inbox.md"
}

obs-note() {
  _obs_require_vault || return 1

  local title="$*"

  if [[ -z "$title" ]]; then
    _obs_err "Usage: obs-note \"Note Title\""
    return 1
  fi

  local slug="$(_obs_slug "$title")"
  local dir="$AZKABAN_VAULT/Notes"
  local file="$dir/$slug.md"

  mkdir -p "$dir"

  if [[ ! -f "$file" ]]; then
    cat > "$file" <<MD
---
type: note
title: "$title"
created: $(_obs_datetime)
tags:
  - note
---

# $title


MD
    _obs_ok "Created note: Notes/$slug.md"
  else
    _obs_info "Note already exists: Notes/$slug.md"
  fi

  _obs_open_file "$file"
}

obs-find() {
  _obs_require_vault || return 1

  local query="$*"

  if [[ -z "$query" ]]; then
    _obs_err "Usage: obs-find \"search text\""
    return 1
  fi

  if command -v rg >/dev/null 2>&1; then
    rg -n --hidden --glob '*.md' "$query" "$AZKABAN_VAULT"
  else
    grep -RIn --include='*.md' "$query" "$AZKABAN_VAULT"
  fi
}

# ---------- project ↔ azkaban actions ----------

obs-project-connect() {
  _obs_require_vault || return 1

  local project_path="${1:-$PWD}"
  local project_name="${2:-${project_path:t}}"

  project_path="$(realpath "$project_path" 2>/dev/null)"

  if [[ -z "$project_path" || ! -d "$project_path" ]]; then
    _obs_err "Project folder not found."
    _obs_info "Usage: obs-project-connect /path/to/project \"Project Name\""
    return 1
  fi

  local slug="$(_obs_slug "$project_name")"
  local title="$(_obs_title "$project_name")"
  local note="$AZKABAN_VAULT/$AZKABAN_PROJECTS_DIR/$slug.md"
  local index="$AZKABAN_VAULT/$AZKABAN_PROJECTS_DIR/_index.md"
  local local_meta_dir="$project_path/.azkaban"
  local local_meta_file="$local_meta_dir/project.md"
  local remote branch git_status package_json docker_compose readme

  remote="$(_obs_git_remote "$project_path")"
  branch="$(_obs_git_branch "$project_path")"
  git_status="$(_obs_git_status_short "$project_path")"

  [[ -f "$project_path/package.json" ]] && package_json="yes" || package_json="no"
  [[ -f "$project_path/docker-compose.yml" || -f "$project_path/compose.yml" ]] && docker_compose="yes" || docker_compose="no"
  [[ -f "$project_path/README.md" ]] && readme="yes" || readme="no"

  mkdir -p "$AZKABAN_VAULT/$AZKABAN_PROJECTS_DIR"
  mkdir -p "$local_meta_dir"

  if [[ ! -f "$note" ]]; then
    cat > "$note" <<MD
---
type: project
project: "$project_name"
slug: "$slug"
path: "$project_path"
created: $(_obs_datetime)
status: active
tags:
  - project
  - azkaban
---

# $title

## Project Identity

| Field | Value |
|---|---|
| Name | $project_name |
| Local Path | \`$project_path\` |
| Git Branch | \`${branch:-none}\` |
| Git Remote | \`${remote:-none}\` |
| Has package.json | $package_json |
| Has Docker Compose | $docker_compose |
| Has README | $readme |

## Mission

Describe the purpose of this project.

## Current Focus

- [ ] Define current sprint objective
- [ ] Document architecture
- [ ] Document setup commands
- [ ] Document known problems

## Commands

\`\`\`zsh
cd "$project_path"
\`\`\`

## Dev Log

### $(_obs_date)

- Connected project with Azkaban.

## Tasks

- [ ] Review project structure
- [ ] Add architecture notes
- [ ] Add migration or setup checklist
- [ ] Add troubleshooting notes

## Links

- Local folder: \`$project_path\`
- Git remote: ${remote:-N/A}

## Snapshots

Run:

\`\`\`zsh
obs-project-snapshot "$project_path"
\`\`\`
MD
    _obs_ok "Created project note: $AZKABAN_PROJECTS_DIR/$slug.md"
  else
    _obs_info "Project note already exists: Projects/$slug.md"
  fi

  if [[ ! -f "$index" ]]; then
    cat > "$index" <<MD
---
type: index
created: $(_obs_datetime)
tags:
  - index
  - projects
---

# Projects

MD
  fi

  if ! grep -q "\[\[$slug\]\]" "$index" 2>/dev/null; then
    print -r -- "- [[$slug]] — \`$project_path\`" >> "$index"
    _obs_ok "Added project to Projects/_index.md"
  fi

  cat > "$local_meta_file" <<MD
# Azkaban Link

This project is connected to the Azkaban Obsidian vault.

| Field | Value |
|---|---|
| Project | $project_name |
| Vault | $AZKABAN_VAULT |
| Note | $AZKABAN_PROJECTS_DIR/$slug.md |
| Connected | $(_obs_datetime) |

Open the vault note:

\`\`\`zsh
obs-open "$AZKABAN_PROJECTS_DIR/$slug.md"
\`\`\`

Update project snapshot:

\`\`\`zsh
obs-project-snapshot "$project_path"
\`\`\`
MD

  _obs_ok "Created local project metadata: .azkaban/project.md"
  _obs_open_file "$note"
}

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

obs-project-snapshot() {
  _obs_require_vault || return 1

  local project_path="${1:-$PWD}"
  local project_name="${2:-${project_path:t}}"

  project_path="$(realpath "$project_path" 2>/dev/null)"

  if [[ -z "$project_path" || ! -d "$project_path" ]]; then
    _obs_err "Project folder not found."
    _obs_info "Usage: obs-project-snapshot /path/to/project \"Project Name\""
    return 1
  fi

  local slug="$(_obs_slug "$project_name")"
  local dir="$AZKABAN_VAULT/$AZKABAN_PROJECTS_DIR/$slug"
  local file="$dir/snapshot-$(_obs_date)-$(date +%H%M%S).md"

  mkdir -p "$dir"

  {
    print -r -- "---"
    print -r -- "type: project-snapshot"
    print -r -- "project: \"$project_name\""
    print -r -- "path: \"$project_path\""
    print -r -- "created: $(_obs_datetime)"
    print -r -- "tags:"
    print -r -- "  - project"
    print -r -- "  - snapshot"
    print -r -- "---"
    print -r -- ""
    print -r -- "# Snapshot — $project_name"
    print -r -- ""
    print -r -- "## Path"
    print -r -- ""
    print -r -- "\`$project_path\`"
    print -r -- ""
    print -r -- "## Git"
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

    if [[ -f "$project_path/docker-compose.yml" ]]; then
      print -r -- ""
      print -r -- "## Docker Compose"
      print -r -- ""
      print -r -- "- Found: \`docker-compose.yml\`"
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

  _obs_ok "Created snapshot: ${file#$AZKABAN_VAULT/}"
  _obs_open_file "$file"
}

obs-projects() {
  _obs_require_vault || return 1

  local dir="$AZKABAN_VAULT/$AZKABAN_PROJECTS_DIR"

  if [[ ! -d "$dir" ]]; then
    _obs_err "No Projects directory found in vault."
    return 1
  fi

  find "$dir" -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sort
}

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

# ---------- git sync for vault ----------

obs-sync() {
  _obs_require_vault || return 1

  local msg="${*:-vault sync: $(_obs_datetime)}"

  if [[ ! -d "$AZKABAN_VAULT/.git" ]]; then
    _obs_err "Vault is not a Git repository: $AZKABAN_VAULT"
    return 1
  fi

  _obs_info "Syncing Azkaban vault..."

  git -C "$AZKABAN_VAULT" add -A

  if ! git -C "$AZKABAN_VAULT" diff --cached --quiet; then
    git -C "$AZKABAN_VAULT" commit -m "$msg"
  else
    _obs_info "No local changes to commit."
  fi

  if git -C "$AZKABAN_VAULT" remote get-url origin >/dev/null 2>&1; then
    git -C "$AZKABAN_VAULT" pull --rebase --autostash
    git -C "$AZKABAN_VAULT" push
    _obs_ok "Vault synced."
  else
    _obs_info "No Git remote configured. Local commit/check complete."
  fi
}

# ---------- aliases ----------

alias az='obs-open'
alias azhome='obs-home'
alias aztoday='obs-today'
alias azcap='obs-capture'
alias aztask='obs-task'
alias azfind='obs-find'
alias azsync='obs-sync'

alias azconnect='obs-connect-current'
alias azsnap='obs-snapshot-current'
alias azlog='obs-log-current'
alias aztodo='obs-task-current'
alias azprojects='obs-projects'
