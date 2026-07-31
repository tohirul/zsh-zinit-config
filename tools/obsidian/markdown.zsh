# ============================================================
# Obsidian / Azkaban — markdown & link helpers
# ============================================================
[[ -n ${_ZSH_TOOL_OBSIDIAN_MARKDOWN:-} ]] && return
typeset -g _ZSH_TOOL_OBSIDIAN_MARKDOWN=1

# Escape a value for use inside a YAML double-quoted scalar
_obs_yaml_escape() {
  print -r -- "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

_obs_wikilink_from_rel() {
  local rel="$1"
  local label="$2"

  rel="${rel%.md}"

  if [[ -n "$label" ]]; then
    print -r -- "[[$rel|$label]]"
  else
    print -r -- "[[$rel]]"
  fi
}

# Safely replace (or append) a fenced block inside a vault note.
#   _obs_append_or_replace_block <file> <block_id>
# Reads the new block body from stdin and appends it to <file>.
_obs_append_or_replace_block() {
  local file="$1"
  local block_id="$2"
  local temp
  temp="$(mktemp)"

  local begin="<!-- AZKABAN:${block_id}:BEGIN -->"
  local end="<!-- AZKABAN:${block_id}:END -->"

  if grep -qF "$begin" "$file" 2>/dev/null; then
    awk -v begin="$begin" -v end="$end" '
      $0 == begin { skip=1; next }
      $0 == end { skip=0; next }
      skip != 1 { print }
    ' "$file" > "$temp"
    mv "$temp" "$file"
  else
    rm -f "$temp"
  fi

  # Append a blank line before the block so it never fuses with the previous
  # line, then write begin-marker, body (from stdin), end-marker.
  {
    print -r -- ""
    print -r -- "$begin"
    cat
    print -r -- "$end"
  } >> "$file"
}
