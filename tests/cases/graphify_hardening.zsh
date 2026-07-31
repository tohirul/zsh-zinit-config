# ============================================================
# Graphify P0/P1 hardening regression tests.
# ============================================================
# Covers: transactional output install/rollback, staging security
# (symlinks/path-escape/secrets/size), query cwd determinism, gfai
# failure propagation, and project-name path-escape rejection.
#
# Most of these fake out `graphify` itself with a zsh shell function
# (command lookup finds a function before the real binary), so they
# stay hermetic and don't require the real `graphify` package to be
# installed. A smaller, explicitly-guarded block at the end exercises
# the real staging security policy end-to-end when the real binary
# IS available, since that's the only way to prove the full pipeline
# (not just the isolated helpers) actually rejects what it should.
# ============================================================

GH_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ztests-gfhard-XXXXXX")"
_gfh_old_pwd="$PWD"

# ---------- _gf_validate_output ----------

gh_good="$GH_TMP/good-out"
mkdir -p "$gh_good"
printf '{"graph":{}}\n' > "$gh_good/graph.json"
printf '# report\n' > "$gh_good/GRAPH_REPORT.md"
_t_ok "validate_output accepts good dir" _gf_validate_output "$gh_good"

gh_missing_report="$GH_TMP/missing-report"
mkdir -p "$gh_missing_report"
printf '{"graph":{}}\n' > "$gh_missing_report/graph.json"
_t_nok "validate_output rejects missing GRAPH_REPORT.md" _gf_validate_output "$gh_missing_report"

gh_bad_json="$GH_TMP/bad-json"
mkdir -p "$gh_bad_json"
printf 'NOT JSON {{{\n' > "$gh_bad_json/graph.json"
printf '# report\n' > "$gh_bad_json/GRAPH_REPORT.md"
_t_nok "validate_output rejects invalid JSON" _gf_validate_output "$gh_bad_json"

gh_empty="$GH_TMP/empty-json"
mkdir -p "$gh_empty"
: > "$gh_empty/graph.json"
printf '# report\n' > "$gh_empty/GRAPH_REPORT.md"
_t_nok "validate_output rejects empty graph.json" _gf_validate_output "$gh_empty"

# ---------- _gf_install_output: rollback on failure ----------

gh_target="$GH_TMP/target-out"
mkdir -p "$gh_target"
printf '{"graph":{"old":true}}\n' > "$gh_target/graph.json"
printf '# old report\n' > "$gh_target/GRAPH_REPORT.md"
gh_orig_hash="$(sha1sum "$gh_target/graph.json")"

_t_nok "install_output rejects invalid new output" _gf_install_output "$gh_bad_json" "$gh_target"
gh_new_hash="$(sha1sum "$gh_target/graph.json")"
_t_eq "target graph.json unchanged after rejected install" "$gh_new_hash" "$gh_orig_hash"
_t_file_contains "target still has old content after rejected install" "$gh_target/graph.json" "old"

_t_ok "install_output accepts valid new output" _gf_install_output "$gh_good" "$gh_target"
_t_file_absent "install_output moved new_dir away (source gone)" "$gh_good"
_t_file_contains "target replaced with new content after accepted install" "$gh_target/graph.json" "graph"

# ---------- _gf_make_stage: unique + private ----------

gh_stage_a="$(GRAPHIFY_CODE_STAGE="$GH_TMP/stage-root" _gf_make_stage)"
gh_stage_b="$(GRAPHIFY_CODE_STAGE="$GH_TMP/stage-root" _gf_make_stage)"
if [[ -n "$gh_stage_a" && -n "$gh_stage_b" && "$gh_stage_a" != "$gh_stage_b" ]]; then
  _t_pass "make_stage produces unique paths across calls"
else
  _t_fail "make_stage produces unique paths across calls" "got [$gh_stage_a] and [$gh_stage_b]"
fi
gh_stage_perm="$(stat -c '%a' "$gh_stage_a" 2>/dev/null)"
_t_eq "make_stage dir is mode 700" "$gh_stage_perm" "700"
rm -rf "$gh_stage_a" "$gh_stage_b"

# ---------- gfaz: project-name path-escape rejection ----------

_t_nok "gfaz rejects name containing '/'" _gf_validate_name "evil/../name"
_t_nok "gfaz rejects name containing '..'" _gf_validate_name "..secret"
_t_ok "gfaz accepts a normal name" _gf_validate_name "My Project"

# ---------- fake-graphify tests (hermetic: no real graphify needed) ----------

gh_repo="$GH_TMP/repo"
mkdir -p "$gh_repo/graphify-out" "$gh_repo/sub"
printf '{"graph":{}}\n' > "$gh_repo/graphify-out/graph.json"
printf '# report\n' > "$gh_repo/graphify-out/GRAPH_REPORT.md"
git -C "$gh_repo" init -q
git -C "$gh_repo" add -A
git -C "$gh_repo" -c user.name=test -c user.email=test@test commit -qm init

# gfq/gfpath/gfexplain must invoke graphify with cwd == resolved repo root,
# even when called from a subdirectory.
graphify() { pwd; }
cd "$gh_repo/sub"
gh_q_pwd="$(gfq "anything" 2>/dev/null)"
_t_eq "gfq runs graphify with cwd == repo root" "$gh_q_pwd" "$gh_repo"
gh_path_pwd="$(gfpath "a" "b" 2>/dev/null)"
_t_eq "gfpath runs graphify with cwd == repo root" "$gh_path_pwd" "$gh_repo"
gh_explain_pwd="$(gfexplain "topic" 2>/dev/null)"
_t_eq "gfexplain runs graphify with cwd == repo root" "$gh_explain_pwd" "$gh_repo"
cd "$gh_repo"
unfunction graphify

# gfai: failing query must not install/overwrite AI_CONTEXT.md or succeed.
printf 'previous good context\n' > "$gh_repo/graphify-out/AI_CONTEXT.md"
graphify() { echo "boom" >&2; return 1; }
cd "$gh_repo"
_t_nok "gfai fails when graphify query fails" gfai "anything"
_t_file_contains "gfai leaves previous AI_CONTEXT.md untouched on failure" "$gh_repo/graphify-out/AI_CONTEXT.md" "previous good context"
gh_leftover_tmp="$(find "$gh_repo/graphify-out" -maxdepth 1 -name '.AI_CONTEXT.md.*' 2>/dev/null)"
_t_eq "gfai cleans up its temp file on failure" "$gh_leftover_tmp" ""
unfunction graphify

# gfai: successful query installs AI_CONTEXT.md.
graphify() { echo "the answer is 42"; return 0; }
_t_ok "gfai succeeds when graphify query succeeds" gfai "anything"
_t_file_contains "gfai installs new AI_CONTEXT.md on success" "$gh_repo/graphify-out/AI_CONTEXT.md" "the answer is 42"
unfunction graphify

# gffull: a failing graphify must leave the previous graphify-out intact.
printf '{"graph":{"keep":true}}\n' > "$gh_repo/graphify-out/graph.json"
printf '# keep me\n' > "$gh_repo/graphify-out/GRAPH_REPORT.md"
graphify() { return 1; }
_t_nok "gffull fails when graphify fails" gffull "" "$gh_repo"
_t_file_contains "gffull preserves previous graphify-out after failure" "$gh_repo/graphify-out/graph.json" "keep"
unfunction graphify

# gffull: a successful graphify that writes valid output installs cleanly.
graphify() {
  mkdir -p graphify-out
  printf '{"graph":{"fresh":true}}\n' > graphify-out/graph.json
  printf '# fresh report\n' > graphify-out/GRAPH_REPORT.md
  return 0
}
_t_ok "gffull succeeds and installs valid output" gffull "" "$gh_repo"
_t_file_contains "gffull installs fresh graphify-out on success" "$gh_repo/graphify-out/graph.json" "fresh"
unfunction graphify

cd "$_gfh_old_pwd"

# ---------- real staging security policy (guarded: needs real graphify) ----------

if command -v graphify >/dev/null 2>&1; then
  gh_sec_repo="$GH_TMP/sec-repo"
  mkdir -p "$gh_sec_repo/src"
  printf 'x = 1\n' > "$gh_sec_repo/src/a.py"
  printf 'SECRET_TOKEN=x\n' > "$gh_sec_repo/src/credentials.json"
  printf 'outside\n' > "$GH_TMP/outside-target.txt"
  ln -s "$GH_TMP/outside-target.txt" "$gh_sec_repo/src/escape.py" 2>/dev/null
  git -C "$gh_sec_repo" init -q
  git -C "$gh_sec_repo" add -A
  git -C "$gh_sec_repo" -c user.name=test -c user.email=test@test commit -qm init

  gh_sec_out="$(GRAPHIFY_KEEP_STAGE=1 GRAPHIFY_CODE_STAGE="$GH_TMP/sec-stage" gfcode "$gh_sec_repo" 2>&1)"
  gh_sec_rc=$?
  _t_eq "real gfcode succeeds on security fixture" "$gh_sec_rc" "0"

  gh_manifest="$(find "$GH_TMP/sec-stage" -maxdepth 2 -name graphify-stage-manifest.json 2>/dev/null | head -1)"
  _t_file_contains "manifest records symlink exclusion" "$gh_manifest" '"symlink"'
  _t_file_contains "manifest records blocklisted (credentials) exclusion" "$gh_manifest" '"blocklisted"'
  _t_file_absent "credentials.json not staged" "${gh_manifest:h}/src/credentials.json"
  _t_file_absent "symlinked escape.py not staged" "${gh_manifest:h}/src/escape.py"

  rm -rf "$GH_TMP/sec-stage"
else
  print -r -- "  (skipping real staging-security block: graphify not installed)"
fi

cd "$_gfh_old_pwd"
rm -rf "$GH_TMP"
