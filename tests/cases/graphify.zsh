# ============================================================
# Graphify split regression tests.
# ============================================================

G_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ztests-gf-XXXXXX")"
_gf_old_pwd="$PWD"

# ---------- _gf_slug edge cases ----------

_t_eq "slug lowercases and dashes spaces" "$(_gf_slug 'My Repo')" "my-repo"
_t_eq "slug keeps dots/underscores/dashes" "$(_gf_slug 'Hello.World-Test_3')" "hello.world-test_3"
_t_eq "slug collapses invalid runs" "$(_gf_slug 'A  B!!C__')" "a--b-c__"
_t_eq "slug trims leading/trailing dashes" "$(_gf_slug '  --X--  ')" "x"

# ---------- _gf_md_section replace / ensure-line ----------

md="$G_TMP/section.md"
_gf_md_section replace "$md" "## Managed" $'one\ntwo'
_t_file_contains "replace creates heading" "$md" "## Managed"
_t_file_contains "replace writes first body line" "$md" "one"
_t_file_contains "replace writes second body line" "$md" "two"
_t_count "replace leaves one heading" "## Managed" "$md" "1"

_gf_md_section replace "$md" "## Managed" "replacement"
_t_count "replace idempotent: one heading" "## Managed" "$md" "1"
_t_count "replace writes new body once" "replacement" "$md" "1"
n="$(grep -cF 'one' "$md" 2>/dev/null)"; n="${n:-0}"
_t_eq "replace removed old body" "$n" "0"

_gf_md_section replace "$G_TMP/nested/dir/file.md" "## H" "body"
_t_file_contains "replace creates parent dirs" "$G_TMP/nested/dir/file.md" "body"

md2="$G_TMP/index.md"
_gf_md_section ensure-line "$md2" "## Project graph index" "- [[x|a]]"
_t_count "ensure-line writes line once" "- [[x|a]]" "$md2" "1"
_gf_md_section ensure-line "$md2" "## Project graph index" "- [[x|a]]"
_t_count "ensure-line does not duplicate" "- [[x|a]]" "$md2" "1"

md3="$G_TMP/mixed.md"
_gf_md_section replace "$md3" "## Index" "keep me"
_gf_md_section ensure-line "$md3" "## Index" "- [[new]]"
_t_file_contains "ensure-line keeps existing lines" "$md3" "keep me"
_t_count "ensure-line adds once beside existing" "- [[new]]" "$md3" "1"

# ---------- gfhelp lists every command ----------

help_out="$(gfhelp)"
for c in gfinstall gfinitignore gfcode gffull gfupdate gfopen gfreport gfjson \
         gfstatus gfq gfpath gfexplain gfai gfaz gfazcopy gfazstatus gfship \
         gfobsidian gfhook gfagents; do
  if [[ "$help_out" == *"$c"* ]]; then
    _t_pass "gfhelp mentions $c"
  else
    _t_fail "gfhelp mentions $c" "missing from output"
  fi
done

# ---------- gfaz bridge notes + hub-index idempotency ----------

export AZKABAN_DIR="$G_TMP/azkaban"
g_repo="$G_TMP/repo"
mkdir -p "$g_repo/graphify-out" "$g_repo/src"
printf 'x = 1\n' > "$g_repo/src/a.py"
printf '{"graph":{}}\n' > "$g_repo/graphify-out/graph.json"
git -C "$g_repo" init -q
git -C "$g_repo" add -A
git -C "$g_repo" -c user.name=test -c user.email=test@test commit -qm init

cd "$g_repo"
gfaz "Graphify Test" >/dev/null 2>&1
rc=$?
_t_eq "gfaz succeeds with graph.json" "$rc" "0"

hub="$AZKABAN_DIR/$GRAPHIFY_WORKSPACE/README.md"
_t_file_contains "gfaz creates hub" "$hub" "# Graphify"
_t_file_contains "hub index lists project" "$hub" "- [[04_AI_Workspace/Graphify/graphify-test/metadata|graphify-test]]"
_t_count "hub index line appears once" "graphify-test/metadata|graphify-test" "$hub" "1"
_t_file_contains "cortext gets Graphify section" "$AZKABAN_DIR/Cortext.md" "Graphify / Generated Project Graphs"
_t_file_contains "metadata note created" "$AZKABAN_DIR/$GRAPHIFY_WORKSPACE/graphify-test/metadata.md" "type: graphify-project"
_t_file_contains "project graph note created" "$AZKABAN_DIR/05_Projects/Active/Project Graph - Graphify Test.md" "type: graphify-index"

gfaz "Graphify Test" >/dev/null 2>&1
rc=$?
_t_eq "gfaz second run succeeds" "$rc" "0"
_t_count "hub index still once after second run" "graphify-test/metadata|graphify-test" "$hub" "1"

rm -f "$g_repo/graphify-out/graph.json"
_t_nok "gfaz fails without graph.json" gfaz "No Graph"
printf '{"graph":{}}\n' > "$g_repo/graphify-out/graph.json"

# ---------- gfinstall missing-script path ----------

ZSH_HOME="$G_TMP/empty-home"
_t_nok "gfinstall fails on missing installer" gfinstall
ZSH_HOME="$REPO_ROOT"

# ---------- gfinitignore ----------

g_repo2="$G_TMP/repo2"
mkdir -p "$g_repo2"
cd "$g_repo2"
gfinitignore >/dev/null 2>&1
_t_file_contains "gfinitignore writes .graphifyignore" "$g_repo2/.graphifyignore" "graphify-out/"
_t_file_contains "gfinitignore appends .gitignore" "$g_repo2/.gitignore" "graphify-out/"

# ---------- loader idempotency ----------

cd "$_gf_old_pwd"
_t_eq "nested part guard set" "${_ZSH_TOOL_GRAPHIFY_CORE:-}" "1"
source "$ZSH_HOME/tools/graphify.zsh"
rc=$?
_t_eq "re-source graphify loader exits 0" "$rc" "0"

# ---------- no repo leak ----------

_t_file_absent "no graphify-out/ leaked into repo" "$REPO_ROOT/graphify-out"

rm -rf "$G_TMP"
