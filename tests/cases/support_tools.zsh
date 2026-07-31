# ============================================================
# Supporting-tool hardening regression tests.
# ============================================================
# Covers: dev_clean project-root guard, git gclean-merged structured
# refs, GPU chromium-family flag gating, VS Code atomic settings
# write, and OpenCode discovery on paths with spaces.
# ============================================================

ST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ztests-support-XXXXXX")"
_st_old_pwd="$PWD"
_st_old_home="$HOME"

# ---------- dev_clean: project-root guard ----------
# Uses a FAKE $HOME (never the real one) so a guard regression can't
# actually delete anything real.

st_fake_home="$ST_TMP/fake-home"
mkdir -p "$st_fake_home"
HOME="$st_fake_home"
cd "$HOME"
out="$(dev_clean --force 2>&1)"
_t_contains "dev_clean --force refuses to run in \$HOME" "$out" "Refusing"
HOME="$_st_old_home"

st_non_project="$ST_TMP/not-a-project"
mkdir -p "$st_non_project"
cd "$st_non_project"
out="$(dev_clean --force 2>&1)"
_t_contains "dev_clean --force refuses a non-project directory" "$out" "Refusing"

st_project="$ST_TMP/project"
mkdir -p "$st_project"
cd "$st_project"
: > package.json
mkdir -p node_modules
dev_clean --force >/dev/null 2>&1
_t_file_absent "dev_clean --force removes node_modules in a real project" "$st_project/node_modules"

cd "$_st_old_pwd"

# ---------- git gclean-merged: structured ref parsing ----------

st_git_repo="$ST_TMP/git-repo"
git init -q -b main "$st_git_repo"
git -C "$st_git_repo" -c user.name=t -c user.email=t@t commit -qm init --allow-empty
git -C "$st_git_repo" branch "feature/done"
git -C "$st_git_repo" branch "feature/pending"

cd "$st_git_repo"
out="$(gclean-merged main 2>&1)"
_t_contains "gclean-merged lists a merged non-default branch" "$out" "  - feature/done"
_t_contains "gclean-merged lists another merged branch" "$out" "  - feature/pending"
if [[ "$out" == *"  - main"* ]]; then
  _t_fail "gclean-merged excludes the base branch itself" "$out"
else
  _t_pass "gclean-merged excludes the base branch itself"
fi
_t_contains "gclean-merged defaults to dry-run" "$out" "Dry-run"
cd "$_st_old_pwd"

# ---------- GPU: chromium-family flag gating ----------

_t_ok "chrome binary is recognized as chromium-family" _prime_is_chromium_family "/usr/bin/google-chrome-stable"
_t_ok "code binary is recognized as chromium-family" _prime_is_chromium_family "code"
_t_nok "blender is NOT recognized as chromium-family" _prime_is_chromium_family "/usr/bin/blender"

# ---------- VS Code: atomic settings write ----------

st_vscode_home="$ST_TMP/vscode-home"
mkdir -p "$st_vscode_home/.config/Code/User"
printf '{"editor.fontSize": 12}\n' > "$st_vscode_home/.config/Code/User/settings.json"

HOME="$st_vscode_home" code_settings_set "editor.fontSize" "14" >/dev/null 2>&1
out="$(HOME="$st_vscode_home" code_settings_get "editor.fontSize" 2>&1)"
_t_eq "code_settings_set writes the new value" "$out" "14"

# temp files must never be left behind in the settings dir
st_leftover="$(find "$st_vscode_home/.config/Code/User" -maxdepth 1 -name '.settings.json.*' 2>/dev/null)"
_t_eq "code_settings_set leaves no leftover temp file" "$st_leftover" ""

# invalid key must fail before touching settings.json
st_hash_before="$(sha1sum "$st_vscode_home/.config/Code/User/settings.json")"
HOME="$st_vscode_home" code_settings_set "not a valid key" "1" >/dev/null 2>&1
st_hash_after="$(sha1sum "$st_vscode_home/.config/Code/User/settings.json")"
_t_eq "code_settings_set with an invalid key leaves settings.json unchanged" "$st_hash_after" "$st_hash_before"

# ---------- OpenCode: discovery handles paths with spaces ----------

st_oc_root="$ST_TMP/oc root with spaces"
mkdir -p "$st_oc_root/my app"
: > "$st_oc_root/my app/package.json"
st_found="$(cd "$st_oc_root" && find . -maxdepth 3 -name package.json -exec dirname {} \; 2>/dev/null)"
_t_eq "find+dirname preserves a path containing spaces as one line" "$st_found" "./my app"

cd "$_st_old_pwd"
HOME="$_st_old_home"
rm -rf "$ST_TMP"
