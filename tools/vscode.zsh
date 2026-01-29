# ============================================================
# VS Code Helpers (Ubuntu, Safe, jq-based)
# ============================================================

# ---------- guards ----------
_code_guard() {
  command -v code >/dev/null 2>&1 || {
    echo "[vscode] code command not found"
    return 1
  }
}

_jq_guard() {
  command -v jq >/dev/null 2>&1 || {
    echo "[vscode] jq not installed (sudo apt install jq)"
    return 1
  }
}

# ---------- paths ----------
_vscode_user_dir() {
  echo "$HOME/.config/Code/User"
}

_vscode_settings() {
  echo "$(_vscode_user_dir)/settings.json"
}

# ---------- open ----------
code_here() {
  _code_guard || return
  code .
}

code_workspace() {
  _code_guard || return
  local ws
  ws=$(ls *.code-workspace 2>/dev/null | head -n 1)
  [[ -n "$ws" ]] && code "$ws" || echo "[vscode] No workspace file found"
}

# ---------- settings ----------
code_settings_backup() {
  local f="$(_vscode_settings)"
  [[ -f "$f" ]] || {
    echo "[vscode] settings.json not found"
    return 1
  }

  cp "$f" "$f.bak.$(date +%s)"
  echo "[vscode] settings backup created"
}

code_settings_edit() {
  _jq_guard || return
  local f="$(_vscode_settings)"
  [[ -f "$f" ]] || {
    echo "{}" > "$f"
  }

  code_settings_backup
  code "$f"
}

code_settings_get() {
  _jq_guard || return
  local key="$1"
  [[ -z "$key" ]] && {
    echo "Usage: code_settings_get <json.key>"
    return 1
  }

  jq ".$key" "$(_vscode_settings)"
}

code_settings_set() {
  _jq_guard || return
  local key="$1"
  local value="$2"

  [[ -z "$key" || -z "$value" ]] && {
    echo "Usage: code_settings_set <json.key> <value>"
    return 1
  }

  local f="$(_vscode_settings)"
  [[ -f "$f" ]] || echo "{}" > "$f"

  code_settings_backup
  tmp=$(mktemp)

  jq ".$key = $value" "$f" > "$tmp" && mv "$tmp" "$f"
  echo "[vscode] Updated $key"
}

# ---------- extensions ----------
code_ext_list() {
  _code_guard || return
  code --list-extensions
}

code_ext_export() {
  _code_guard || return
  code --list-extensions > vscode-extensions.txt
  echo "[vscode] Extensions exported to vscode-extensions.txt"
}

code_ext_import() {
  _code_guard || return
  [[ -f vscode-extensions.txt ]] || {
    echo "[vscode] vscode-extensions.txt not found"
    return 1
  }

  while read -r ext; do
    code --install-extension "$ext"
  done < vscode-extensions.txt
}

# ---------- workspace bootstrap ----------
code_bootstrap() {
  _code_guard || return
  echo "Bootstrapping VS Code project…"

  [[ -f .editorconfig ]] || cat > .editorconfig <<EOF
root = true

[*]
indent_style = space
indent_size = 2
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
EOF

  mkdir -p .vscode

  [[ -f .vscode/settings.json ]] || cat > .vscode/settings.json <<EOF
{
  "editor.formatOnSave": true,
  "files.trimTrailingWhitespace": true
}
EOF

  code .
}
