# ============================================================
# Obsidian / Azkaban — markdown & link helpers
# ============================================================
[[ -n ${_ZSH_TOOL_OBSIDIAN_MARKDOWN:-} ]] && return
typeset -g _ZSH_TOOL_OBSIDIAN_MARKDOWN=1

# Escape a value for use inside a YAML double-quoted scalar. Newlines are
# collapsed to spaces — a literal newline in a quoted scalar would break
# the frontmatter block structure.
_obs_yaml_escape() {
  print -rn -- "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '
}

# Escape a value for use inside a GFM table cell / inline code span:
# pipes break the column structure, backticks break code spans, and
# newlines break the row entirely.
_obs_md_table_escape() {
  print -rn -- "$1" | sed 's/|/\\|/g; s/`/'"'"'/g' | tr '\n' ' '
}

_obs_wikilink_from_rel() {
  local rel="$1"
  local label="$2"

  rel="${rel%.md}"
  # A raw ']]' or '|' in the label would break wikilink syntax.
  label="$(print -r -- "$label" | sed 's/\]\]//g; s/|/-/g')"

  if [[ -n "$label" ]]; then
    print -r -- "[[$rel|$label]]"
  else
    print -r -- "[[$rel]]"
  fi
}

# Safely replace (or append) a managed block inside a vault note.
#   _obs_append_or_replace_block <file> <block_id>
# Reads the new block body from stdin.
#
# Valid marker states are exactly: 0 BEGIN + 0 END (append a fresh block),
# or 1 BEGIN + 1 END with BEGIN before END (replace it). Any other state
# (a missing END, duplicate markers, reversed order) is refused outright —
# the original file is left completely untouched and the function returns
# non-zero. The old code used an awk skip-toggle that silently dropped
# everything to EOF when END was missing; that data-loss path no longer
# exists. The rewrite is also atomic: the whole new file is assembled in a
# same-directory temp file and only then renamed over the original, so a
# crash mid-write can never leave a half-written note.
_obs_append_or_replace_block() {
  local file="$1"
  local block_id="$2"
  local body
  body="$(cat)"

  local begin="<!-- AZKABAN:${block_id}:BEGIN -->"
  local end="<!-- AZKABAN:${block_id}:END -->"

  local begin_count=0 end_count=0
  if [[ -f "$file" ]]; then
    begin_count="$(grep -cF -- "$begin" "$file" 2>/dev/null)"
    end_count="$(grep -cF -- "$end" "$file" 2>/dev/null)"
  fi

  local kept=""
  if (( begin_count == 0 && end_count == 0 )); then
    [[ -f "$file" ]] && kept="$(cat "$file")"
  elif (( begin_count == 1 && end_count == 1 )); then
    local begin_line end_line
    begin_line="$(grep -nF -- "$begin" "$file" | head -1 | cut -d: -f1)"
    end_line="$(grep -nF -- "$end" "$file" | head -1 | cut -d: -f1)"
    if (( begin_line >= end_line )); then
      _obs_err "Malformed managed block '$block_id' in $file (END appears before BEGIN); file left untouched."
      return 1
    fi
    kept="$(awk -v begin="$begin" -v end="$end" '
      $0 == begin { skip=1; next }
      $0 == end { skip=0; next }
      skip != 1 { print }
    ' "$file")"
  else
    _obs_err "Malformed managed block '$block_id' in $file (found $begin_count BEGIN / $end_count END marker(s), expected 0 or 1 of each); file left untouched."
    return 1
  fi

  local tmp
  tmp="$(mktemp "${file:h}/.$(basename -- "$file").XXXXXXXX")" || {
    _obs_err "Could not create a temp file next to $file"
    return 1
  }

  {
    [[ -n "$kept" ]] && print -r -- "$kept"
    print -r -- ""
    print -r -- "$begin"
    print -r -- "$body"
    print -r -- "$end"
  } > "$tmp"

  if [[ -f "$file" ]]; then
    local mode
    mode="$(stat -c '%a' "$file" 2>/dev/null)"
    [[ -n "$mode" ]] && chmod "$mode" -- "$tmp" 2>/dev/null
  fi

  mv -- "$tmp" "$file"
}
