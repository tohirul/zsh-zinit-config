# ============================================================
# Obsidian split regression tests.
# ============================================================

O_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ztests-obs-XXXXXX")"

# ---------- markdown helpers ----------

out="$(_obs_yaml_escape 'He said "hi" \ back')"
_t_eq "yaml_escape doubles backslashes + quotes" "$out" 'He said \"hi\" \\ back'

out="$(_obs_wikilink_from_rel "05_Projects/Active/Note.md" "Label")"
_t_eq "wikilink with label" "$out" '[[05_Projects/Active/Note|Label]]'

out="$(_obs_wikilink_from_rel "05_Projects/Active/Note.md")"
_t_eq "wikilink without label" "$out" '[[05_Projects/Active/Note]]'

block="$O_TMP/note.md"
printf '# Note\n\nSome content.\n\n<!-- AZKABAN:LATEST-SNAPSHOT:BEGIN -->\n- old snapshot\n<!-- AZKABAN:LATEST-SNAPSHOT:END -->\n\nTail.\n' > "$block"
print -r -- "- new snapshot" | _obs_append_or_replace_block "$block" "LATEST-SNAPSHOT"
_t_file_contains "block replace keeps new content" "$block" "- new snapshot"
_t_file_absent "block replace removed old content" "$O_TMP/old-check" && ! grep -qF "old snapshot" "$block" && _t_pass "block replace removed old snapshot" || _t_fail "block replace removed old snapshot" "old snapshot still present"
_t_count "block replace leaves exactly one BEGIN" "AZKABAN:LATEST-SNAPSHOT:BEGIN" "$block" "1"
_t_count "block replace leaves exactly one END" "AZKABAN:LATEST-SNAPSHOT:END" "$block" "1"

# ---------- project connect / bind / snapshot ----------

export AZKABAN_VAULT="$O_TMP/vault"
mkdir -p "$AZKABAN_VAULT"
repo="$O_TMP/repo"
mkdir -p "$repo/src"
printf 'x = 1\n' > "$repo/src/app.py"
printf '{\n  "name": "t",\n  "scripts": {"dev": "echo hi"}\n}\n' > "$repo/package.json"
printf '# README\n' > "$repo/README.md"
printf 'services:\n  app:\n    image: nginx\n' > "$repo/docker-compose.yml"
git -C "$repo" init -q
git -C "$repo" add -A
git -C "$repo" -c user.name=test -c user.email=test@test commit -qm init

_t_ok "obs-project-connect succeeds" obs-project-connect "$repo" "Test Project"

note="$AZKABAN_VAULT/05_Projects/Active/test-project.md"
_t_file_contains "connect creates project note" "$note" "type: project"
_t_file_contains "connect yaml-escapes path in frontmatter" "$note" "path: \"$repo\""
_t_file_contains "bind writes .azkaban/project.md" "$repo/.azkaban/project.md" "| Note |"
_t_file_contains "bind writes REPO-CONNECTION block" "$note" "AZKABAN:REPO-CONNECTION:BEGIN"
_t_file_contains "bind indexes project" "$AZKABAN_VAULT/05_Projects/Active/_index.md" "[[05_Projects/Active/test-project|Test Project]]"

obs-project-snapshot "$repo" "Test Project" >/dev/null 2>&1
obs-project-snapshot "$repo" "Test Project" >/dev/null 2>&1

snap_dir="$AZKABAN_VAULT/05_Projects/Active/test-project"
snap="$(ls "$snap_dir"/snapshot-*.md 2>/dev/null | tail -1)"
[[ -n "$snap" ]] && _t_pass "snapshot file created" || _t_fail "snapshot file created" "no snapshot-*.md in $snap_dir"
_t_count "two snapshots leave exactly one LATEST-SNAPSHOT block" "AZKABAN:LATEST-SNAPSHOT:BEGIN" "$note" "1"
_t_file_contains "snapshot links back to project note" "$snap" "Project note: [[05_Projects/Active/test-project|Test Project]]"
_t_file_contains "snapshot has Git Status section" "$snap" "## Git Status"
_t_file_contains "snapshot has Branch section" "$snap" "## Branch"
_t_file_contains "snapshot has package.json Scripts section" "$snap" "## package.json Scripts"
_t_file_contains "snapshot has Docker Compose section" "$snap" "## Docker Compose"
_t_file_contains "snapshot has README Preview section" "$snap" "## README Preview"

_t_nok "obs-project-bind on missing note fails" obs-project-bind "$repo" "05_Projects/Active/Missing.md" "X"

# ---------- capture / task (no xdg-open) ----------

export AZKABAN_VAULT="$O_TMP/notes-vault"
mkdir -p "$AZKABAN_VAULT"
_t_ok "obs-capture succeeds" obs-capture "hello world"
_t_file_contains "capture appends to inbox" "$AZKABAN_VAULT/00_Inbox/Inbox.md" "- "
_t_ok "obs-task succeeds" obs-task "do the thing" "MyProj"
_t_file_contains "task appended to tasks file" "$AZKABAN_VAULT/02_Tasks/inbox.md" "do the thing"

# ---------- sync dry-run (no commit) ----------

export AZKABAN_VAULT="$O_TMP/sync-vault"
mkdir -p "$AZKABAN_VAULT"
git -C "$AZKABAN_VAULT" init -q
printf 'a\n' > "$AZKABAN_VAULT/a.md"
git -C "$AZKABAN_VAULT" add -A
git -C "$AZKABAN_VAULT" -c user.name=test -c user.email=test@test commit -qm init
printf 'b\n' >> "$AZKABAN_VAULT/a.md"
before="$(git -C "$AZKABAN_VAULT" log --oneline | wc -l | tr -d ' ')"
obs-sync --dry-run >/dev/null 2>&1
rc=$?
_t_eq "sync --dry-run exits 0" "$rc" "0"
after="$(git -C "$AZKABAN_VAULT" log --oneline | wc -l | tr -d ' ')"
_t_eq "sync --dry-run does not commit" "$after" "$before"

rm -rf "$O_TMP"
