# ============================================================
# VS Code Helpers (Drop-in, Hardened, jq-based)
# Ubuntu / Safe / Deterministic
# ============================================================
[[ -n ${_ZSH_TOOL_VSCODE:-} ]] && return
typeset -g _ZSH_TOOL_VSCODE=1

# ----------------------------
# Guards (_code_guard / _jq_guard provided by lib/utils.zsh)
# ----------------------------

# ----------------------------
# Paths
# ----------------------------

_vscode_user_dir() {
  echo "$HOME/.config/Code/User"
}

_vscode_settings() {
  echo "$(_vscode_user_dir)/settings.json"
}

# ----------------------------
# Open helpers
# ----------------------------

code_here() {
  _code_guard || return 1
  code .
}

code_workspace() {
  _code_guard || return 1

  local ws
  ws=$(ls *.code-workspace 2>/dev/null | head -n 1)

  if [[ -n "$ws" ]]; then
    code "$ws"
  else
    echo "[vscode] No .code-workspace file found"
    return 1
  fi
}

# ----------------------------
# Settings helpers
# ----------------------------

code_settings_backup() {
  local f
  f="$(_vscode_settings)"

  [[ -f "$f" ]] || {
    echo "[vscode] settings.json not found"
    return 1
  }

  cp "$f" "$f.bak.$(date +%s)"
  echo "[vscode] settings backup created"
}

code_settings_edit() {
  _code_guard || return 1
  _jq_guard   || return 1

  local f
  f="$(_vscode_settings)"

  mkdir -p "$(dirname "$f")"
  [[ -f "$f" ]] || echo "{}" > "$f"

  code_settings_backup
  code "$f"
}

code_settings_get() {
  _jq_guard || return 1

  local key="$1"
  [[ -z "$key" ]] && {
    echo "Usage: code_settings_get <json.key>"
    return 1
  }
  [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$ ]] || {
    echo "[vscode] invalid key (use a dotted JSON path, e.g. editor.fontSize)"
    return 1
  }

  local f
  f="$(_vscode_settings)"
  [[ -f "$f" ]] || {
    echo "[vscode] settings.json not found"
    return 1
  }

  jq ".$key" "$f"
}

code_settings_set() {
  _jq_guard || return 1

  local key="$1"
  local value="$2"

  [[ -z "$key" || -z "$value" ]] && {
    echo "Usage: code_settings_set <json.key> <json_value>"
    echo "  json_value may be any JSON literal (\"str\", 42, true) or plain text"
    return 1
  }
  [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$ ]] || {
    echo "[vscode] invalid key (use a dotted JSON path, e.g. editor.fontSize)"
    return 1
  }

  local f tmp
  f="$(_vscode_settings)"
  mkdir -p "$(dirname "$f")"
  [[ -f "$f" ]] || echo "{}" > "$f"

  code_settings_backup || return 1
  # Same directory as the target so the final `mv` is an atomic rename,
  # not a cross-filesystem copy (mktemp defaults to $TMPDIR).
  tmp="$(mktemp "$(dirname "$f")/.settings.json.XXXXXXXX")" || return 1
  trap 'rm -f "$tmp"' EXIT

  # Values are passed as --arg/--argjson so the value can never inject jq code.
  local write_ok=0
  if jq -e . >/dev/null 2>&1 <<<"$value"; then
    jq --argjson value "$value" ".${key} = \$value" "$f" > "$tmp" && mv -- "$tmp" "$f" && write_ok=1
  else
    jq --arg value "$value" ".${key} = \$value" "$f" > "$tmp" && mv -- "$tmp" "$f" && write_ok=1
  fi

  if (( write_ok )); then
    echo "[vscode] Updated setting: $key"
  else
    echo "[vscode] Failed to update setting: $key (settings.json left unchanged)" >&2
    rm -f -- "$tmp"
    return 1
  fi
}

# ----------------------------
# Extensions
# ----------------------------

code_ext_list() {
  _code_guard || return 1
  code --list-extensions
}

code_ext_export() {
  _code_guard || return 1

  code --list-extensions > vscode-extensions.txt
  echo "[vscode] Extensions exported → vscode-extensions.txt"
}

code_ext_import() {
  _code_guard || return 1

  [[ -f vscode-extensions.txt ]] || {
    echo "[vscode] vscode-extensions.txt not found"
    return 1
  }

  while read -r ext; do
    [[ -n "$ext" ]] && code --install-extension "$ext"
  done < vscode-extensions.txt
}

# ----------------------------
# Workspace bootstrap
# ----------------------------

code_bootstrap() {
  _code_guard || return 1

  echo "[vscode] Bootstrapping project…"

  # editorconfig
  [[ -f .editorconfig ]] || cat > .editorconfig <<'EOF'
root = true

[*]
indent_style = space
indent_size = 2
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
EOF

  # vscode dir
  mkdir -p .vscode

  # workspace settings
  [[ -f .vscode/settings.json ]] || cat > .vscode/settings.json <<'EOF'
{
  "editor.formatOnSave": true,
  "files.trimTrailingWhitespace": true
}
EOF

  code .
}
