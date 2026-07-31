# ============================================================
# Obsidian / Azkaban — core helpers (layout, guards, basics)
# ============================================================
[[ -n ${_ZSH_TOOL_OBSIDIAN_CORE:-} ]] && return
typeset -g _ZSH_TOOL_OBSIDIAN_CORE=1

# Numbered Azkaban layout (override all in $ZSH_HOME/local.zsh)
export AZKABAN_VAULT="${AZKABAN_VAULT:-$HOME/azkaban}"
export AZKABAN_INBOX_DIR="${AZKABAN_INBOX_DIR:-00_Inbox}"
export AZKABAN_INBOX_FILE="${AZKABAN_INBOX_FILE:-Inbox.md}"
export AZKABAN_DAILY_DIR="${AZKABAN_DAILY_DIR:-01_Daily/Daily Notes}"
export AZKABAN_TASKS_DIR="${AZKABAN_TASKS_DIR:-02_Tasks}"
export AZKABAN_TASKS_FILE="${AZKABAN_TASKS_FILE:-inbox.md}"
export AZKABAN_NOTES_DIR="${AZKABAN_NOTES_DIR:-10_Knowledge_Base/Atomic Notes}"
export AZKABAN_PROJECTS_DIR="${AZKABAN_PROJECTS_DIR:-05_Projects/Active}"
export AZKABAN_AUTO_OPEN="${AZKABAN_AUTO_OPEN:-0}"
export OBSIDIAN_VAULT_NAME="${OBSIDIAN_VAULT_NAME:-$(basename "$AZKABAN_VAULT")}"

# ---------- message helpers ----------

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

# ---------- string / date helpers ----------

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

_obs_datetime() {
  date +"%Y-%m-%d %H:%M:%S"
}

_obs_urlencode() {
  python3 - "$1" <<'PY'
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
}

# ---------- vault open ----------

_obs_open_file() {
  local file="$1"
  local rel="${file#$AZKABAN_VAULT/}"
  local encoded_vault encoded_file

  encoded_vault="$(_obs_urlencode "$OBSIDIAN_VAULT_NAME")"
  encoded_file="$(_obs_urlencode "$rel")"

  xdg-open "obsidian://open?vault=${encoded_vault}&file=${encoded_file}" >/dev/null 2>&1 &
}

# ---------- git helpers ----------

_obs_git_remote() {
  git -C "$1" remote get-url origin 2>/dev/null || true
}

_obs_git_branch() {
  git -C "$1" branch --show-current 2>/dev/null || true
}

_obs_git_status_short() {
  git -C "$1" status --short 2>/dev/null || true
}
