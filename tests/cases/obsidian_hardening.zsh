# ============================================================
# Obsidian P0/P1 hardening regression tests.
# ============================================================
# Covers: malformed managed-block rejection (no data loss), obs-sync
# failure propagation (no false "synced"), AZKABAN_AUTO_OPEN gating,
# snapshot filename collision-safety, and table/YAML escaping.
# ============================================================

OH_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ztests-obshard-XXXXXX")"
_oh_old_pwd="$PWD"

# ---------- malformed managed blocks: original must survive untouched ----------

oh_missing_end="$OH_TMP/missing-end.md"
printf '# Note\n\n<!-- AZKABAN:X:BEGIN -->\nold body, no end marker\n' > "$oh_missing_end"
oh_hash_before="$(sha1sum "$oh_missing_end")"
print -r -- "new body" | _obs_append_or_replace_block "$oh_missing_end" "X" 2>/dev/null
_t_ok "missing END is rejected (nonzero)" test "$?" -ne 0
oh_hash_after="$(sha1sum "$oh_missing_end")"
_t_eq "missing-END file is byte-for-byte unchanged" "$oh_hash_after" "$oh_hash_before"

oh_dup_begin="$OH_TMP/dup-begin.md"
printf '<!-- AZKABAN:X:BEGIN -->\na\n<!-- AZKABAN:X:BEGIN -->\nb\n<!-- AZKABAN:X:END -->\n' > "$oh_dup_begin"
oh_hash_before="$(sha1sum "$oh_dup_begin")"
print -r -- "new body" | _obs_append_or_replace_block "$oh_dup_begin" "X" 2>/dev/null
oh_rc=$?
_t_ok "duplicate BEGIN is rejected (nonzero)" test "$oh_rc" -ne 0
oh_hash_after="$(sha1sum "$oh_dup_begin")"
_t_eq "duplicate-BEGIN file is byte-for-byte unchanged" "$oh_hash_after" "$oh_hash_before"

oh_dup_end="$OH_TMP/dup-end.md"
printf '<!-- AZKABAN:X:BEGIN -->\na\n<!-- AZKABAN:X:END -->\nb\n<!-- AZKABAN:X:END -->\n' > "$oh_dup_end"
oh_hash_before="$(sha1sum "$oh_dup_end")"
print -r -- "new body" | _obs_append_or_replace_block "$oh_dup_end" "X" 2>/dev/null
oh_rc=$?
_t_ok "duplicate END is rejected (nonzero)" test "$oh_rc" -ne 0
oh_hash_after="$(sha1sum "$oh_dup_end")"
_t_eq "duplicate-END file is byte-for-byte unchanged" "$oh_hash_after" "$oh_hash_before"

oh_reversed="$OH_TMP/reversed.md"
printf '<!-- AZKABAN:X:END -->\na\n<!-- AZKABAN:X:BEGIN -->\n' > "$oh_reversed"
oh_hash_before="$(sha1sum "$oh_reversed")"
print -r -- "new body" | _obs_append_or_replace_block "$oh_reversed" "X" 2>/dev/null
oh_rc=$?
_t_ok "reversed END-before-BEGIN is rejected (nonzero)" test "$oh_rc" -ne 0
oh_hash_after="$(sha1sum "$oh_reversed")"
_t_eq "reversed-markers file is byte-for-byte unchanged" "$oh_hash_after" "$oh_hash_before"

# Sanity: a well-formed single pair is still accepted (already covered in
# obsidian.zsh, repeated here for a file with no trailing newline).
oh_no_trailing_nl="$OH_TMP/no-trailing-nl.md"
printf '<!-- AZKABAN:X:BEGIN -->\nold\n<!-- AZKABAN:X:END -->' > "$oh_no_trailing_nl"
print -r -- "new" | _obs_append_or_replace_block "$oh_no_trailing_nl" "X"
_t_eq "well-formed block without trailing newline still accepted" "$?" "0"
_t_file_contains "well-formed replace applied new body" "$oh_no_trailing_nl" "new"

# ---------- obs-sync: no false success on git failures ----------

oh_sync_vault="$OH_TMP/sync-vault"
mkdir -p "$oh_sync_vault"
git -C "$oh_sync_vault" init -q
printf 'a\n' > "$oh_sync_vault/a.md"
git -C "$oh_sync_vault" add -A
git -C "$oh_sync_vault" -c user.name=t -c user.email=t@t commit -qm init

# commit failure: a rejecting pre-commit hook
mkdir -p "$oh_sync_vault/.git/hooks"
cat > "$oh_sync_vault/.git/hooks/pre-commit" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$oh_sync_vault/.git/hooks/pre-commit"
printf 'b\n' >> "$oh_sync_vault/a.md"

out="$(AZKABAN_VAULT="$oh_sync_vault" obs-sync 2>&1)"
oh_sync_rc=$?
_t_ok "obs-sync fails when commit is rejected by a hook" test "$oh_sync_rc" -ne 0
if [[ "$out" == *"Vault synced"* ]]; then
  _t_fail "obs-sync does not claim success after a rejected commit" "$out"
else
  _t_pass "obs-sync does not claim success after a rejected commit"
fi
rm -f "$oh_sync_vault/.git/hooks/pre-commit"
git -C "$oh_sync_vault" checkout -q -- a.md 2>/dev/null || git -C "$oh_sync_vault" reset -q --hard 2>/dev/null

# push failure: remote points at a nonexistent path
git -C "$oh_sync_vault" remote add origin "$OH_TMP/does-not-exist"
printf 'c\n' >> "$oh_sync_vault/a.md"
out="$(AZKABAN_VAULT="$oh_sync_vault" obs-sync 2>&1)"
oh_sync_rc=$?
_t_ok "obs-sync fails when push has no reachable remote" test "$oh_sync_rc" -ne 0
if [[ "$out" == *"Vault synced"* ]]; then
  _t_fail "obs-sync does not claim success after a failed push" "$out"
else
  _t_pass "obs-sync does not claim success after a failed push"
fi

# ---------- AZKABAN_AUTO_OPEN gating ----------

oh_open_vault="$OH_TMP/open-vault"
mkdir -p "$oh_open_vault/$AZKABAN_NOTES_DIR" "$oh_open_vault/$AZKABAN_DAILY_DIR"
oh_open_marker="$OH_TMP/xdg-open-called"

xdg-open() { print -r -- "called: $*" >> "$oh_open_marker"; }

rm -f "$oh_open_marker"
AZKABAN_VAULT="$oh_open_vault" AZKABAN_AUTO_OPEN=0 obs-today >/dev/null 2>&1
_t_file_absent "AZKABAN_AUTO_OPEN=0: obs-today does not launch xdg-open" "$oh_open_marker"

rm -f "$oh_open_marker"
AZKABAN_VAULT="$oh_open_vault" AZKABAN_AUTO_OPEN=1 obs-today >/dev/null 2>&1
sleep 0.05
_t_file_contains "AZKABAN_AUTO_OPEN=1: obs-today launches xdg-open" "$oh_open_marker" "called:"

unfunction xdg-open

# ---------- snapshot filename collision-safety ----------

oh_snap_vault="$OH_TMP/snap-vault"
oh_snap_repo="$OH_TMP/snap-repo"
mkdir -p "$oh_snap_vault" "$oh_snap_repo"
git -C "$oh_snap_repo" init -q
git -C "$oh_snap_repo" add -A 2>/dev/null
git -C "$oh_snap_repo" -c user.name=t -c user.email=t@t commit -qm init --allow-empty >/dev/null

AZKABAN_VAULT="$oh_snap_vault" obs-project-snapshot "$oh_snap_repo" "Collision Test" >/dev/null 2>&1
AZKABAN_VAULT="$oh_snap_vault" obs-project-snapshot "$oh_snap_repo" "Collision Test" >/dev/null 2>&1
oh_snap_count="$(find "$oh_snap_vault/$AZKABAN_PROJECTS_DIR/collision-test" -maxdepth 1 -name 'snapshot-*.md' 2>/dev/null | wc -l | tr -d ' ')"
_t_eq "two immediate snapshots produce two distinct files" "$oh_snap_count" "2"

# ---------- escaping helpers ----------

out="$(_obs_md_table_escape 'a | b `c` d')"
_t_eq "md_table_escape escapes pipe and backtick" "$out" 'a \| b '"'"'c'"'"' d'

out="$(_obs_yaml_escape $'line1\nline2')"
_t_eq "yaml_escape collapses embedded newline" "$out" "line1 line2"

out="$(_obs_wikilink_from_rel "a/b.md" 'weird ]] | label')"
_t_eq "wikilink_from_rel sanitizes ]] and | in label" "$out" '[[a/b|weird  - label]]'

cd "$_oh_old_pwd"
rm -rf "$OH_TMP"
