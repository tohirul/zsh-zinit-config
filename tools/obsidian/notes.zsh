# ============================================================
# Obsidian / Azkaban — vault note actions
# ============================================================
[[ -n ${_ZSH_TOOL_OBSIDIAN_NOTES:-} ]] && return
typeset -g _ZSH_TOOL_OBSIDIAN_NOTES=1

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

  local dir="$AZKABAN_VAULT/$AZKABAN_DAILY_DIR"
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
    _obs_ok "Created daily note: $AZKABAN_DAILY_DIR/$(_obs_date).md"
  else
    _obs_info "Daily note already exists: $AZKABAN_DAILY_DIR/$(_obs_date).md"
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

  local dir="$AZKABAN_VAULT/$AZKABAN_INBOX_DIR"
  local file="$dir/$AZKABAN_INBOX_FILE"

  mkdir -p "$dir"
  touch "$file"

  cat >> "$file" <<MD

- $(_obs_datetime) — $text
MD

  _obs_ok "Captured to $AZKABAN_INBOX_DIR/$AZKABAN_INBOX_FILE"
}

obs-task() {
  _obs_require_vault || return 1

  local task="$1"
  local project="$2"

  if [[ -z "$task" ]]; then
    _obs_err "Usage: obs-task \"task text\" [project-name]"
    return 1
  fi

  local dir="$AZKABAN_VAULT/$AZKABAN_TASKS_DIR"
  local file="$dir/$AZKABAN_TASKS_FILE"

  mkdir -p "$dir"
  touch "$file"

  if [[ -n "$project" ]]; then
    print -r -- "- [ ] $task #task #project/[[$project]] 📥 $(_obs_date)" >> "$file"
  else
    print -r -- "- [ ] $task #task 📥 $(_obs_date)" >> "$file"
  fi

  _obs_ok "Task added to $AZKABAN_TASKS_DIR/$AZKABAN_TASKS_FILE"
}

obs-note() {
  _obs_require_vault || return 1

  local title="$*"

  if [[ -z "$title" ]]; then
    _obs_err "Usage: obs-note \"Note Title\""
    return 1
  fi

  local slug="$(_obs_slug "$title")"
  local dir="$AZKABAN_VAULT/$AZKABAN_NOTES_DIR"
  local file="$dir/$slug.md"
  local title_esc="$(_obs_yaml_escape "$title")"

  mkdir -p "$dir"

  if [[ ! -f "$file" ]]; then
    cat > "$file" <<MD
---
type: note
title: "$title_esc"
created: $(_obs_datetime)
tags:
  - note
---

# $title


MD
    _obs_ok "Created note: $AZKABAN_NOTES_DIR/$slug.md"
  else
    _obs_info "Note already exists: $AZKABAN_NOTES_DIR/$slug.md"
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
