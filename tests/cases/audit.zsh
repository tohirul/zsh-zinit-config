# ============================================================
# Audit self-tests.
# ============================================================
# zsh_audit's checks [12]/[13]/[18]/[19]/[20] used to compute a local
# counter that was never folded into the aggregate rc_failures, so a
# duplicate function/alias or a hardcoded path could print a red FAIL
# line and still leave the audit reporting overall success. These
# tests build a hermetic fixture copy of the real framework (own
# HOME, own ZSH_HOME, own mirrored ~/.zshrc) so zsh_audit's result is
# fully deterministic, then assert: a clean copy passes, and a copy
# with known-bad patterns injected fails with the specific messages.
# ============================================================

A_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ztests-audit-XXXXXX")"

_audit_test_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  cp -a "$REPO_ROOT/lib" "$REPO_ROOT/tools" "$dir/"
  cp "$REPO_ROOT/aliases.zsh" "$REPO_ROOT/functions.zsh" "$REPO_ROOT/zsh_backuprc.zsh" \
     "$REPO_ROOT/local.env.zsh.example" "$REPO_ROOT/local.zsh.example" "$dir/"
  local home="$dir-home"
  mkdir -p "$home"
  cp "$dir/zsh_backuprc.zsh" "$home/.zshrc"
  print -r -- "$home"
}

_audit_test_run() {
  local fixture="$1" home="$2"
  HOME="$home" ZSH_HOME="$fixture" zsh -f -c '
    source "$ZSH_HOME/lib/errors.zsh"
    source "$ZSH_HOME/lib/utils.zsh"
    source "$ZSH_HOME/tools/audit.zsh"
    zsh_audit
  ' 2>&1
}

# ---------- clean fixture: no false positives on real code ----------
# (Not asserting overall rc==0/"audit passed" here: check [6]'s startup
# benchmark runs a real `zsh -i -c exit` against a brand-new, cold
# $HOME with no cached zcompdump, which can push compinit's one-time
# security-check pass over the hard-fail threshold — an environment
# artifact, not a correctness signal. What this test cares about is
# that checks [12]/[13]/[18]/[19]/[20] don't misfire on real code.)

a_clean="$A_TMP/clean"
a_clean_home="$(_audit_test_fixture "$a_clean")"
a_clean_out="$(_audit_test_run "$a_clean" "$a_clean_home")"

if [[ "$a_clean_out" == *"defined in multiple modules"* ]]; then
  _t_fail "clean fixture: no duplicate-function/alias false positive" "$a_clean_out"
else
  _t_pass "clean fixture: no duplicate-function/alias false positive"
fi
if [[ "$a_clean_out" == *"is defined as both an alias and a function"* ]]; then
  _t_fail "clean fixture: no alias/function collision false positive" "$a_clean_out"
else
  _t_pass "clean fixture: no alias/function collision false positive"
fi
if [[ "$a_clean_out" == *"used in multiple modules"* ]]; then
  _t_fail "clean fixture: no duplicate-guard false positive" "$a_clean_out"
else
  _t_pass "clean fixture: no duplicate-guard false positive"
fi
if [[ "$a_clean_out" == *"contains a machine-specific absolute path"* ]]; then
  _t_fail "clean fixture: no hardcoded-path false positive" "$a_clean_out"
else
  _t_pass "clean fixture: no hardcoded-path false positive"
fi

# ---------- bad fixture: inject known-bad patterns ----------

a_bad="$A_TMP/bad"
a_bad_home="$(_audit_test_fixture "$a_bad")"

cat > "$a_bad/tools/_fixture_bad_a.zsh" <<'EOF'
[[ -n ${_ZSH_FIXTURE_BAD_A:-} ]] && return
typeset -g _ZSH_FIXTURE_BAD_A=1
typeset -g _ZSH_FIXTURE_DUP_GUARD=1
alias _audit_selftest_dup_alias='true'
alias _audit_selftest_collision='true'
_audit_selftest_dup_fn() { : }
# leaked machine path for the portability check:
# /home/testuser/leaky/path
EOF

cat > "$a_bad/tools/_fixture_bad_b.zsh" <<'EOF'
[[ -n ${_ZSH_FIXTURE_BAD_B:-} ]] && return
typeset -g _ZSH_FIXTURE_BAD_B=1
typeset -g _ZSH_FIXTURE_DUP_GUARD=1
alias _audit_selftest_dup_alias='true'
_audit_selftest_collision() { : }
_audit_selftest_dup_fn() { : }
EOF

a_bad_out="$(_audit_test_run "$a_bad" "$a_bad_home")"
a_bad_rc=$?

_t_ok "bad fixture audit exits non-zero" test "$a_bad_rc" -ne 0
_t_contains "reports duplicate function" "$a_bad_out" "_audit_selftest_dup_fn' defined in multiple modules"
_t_contains "reports duplicate alias" "$a_bad_out" "alias '_audit_selftest_dup_alias' defined in multiple modules"
_t_contains "reports alias/function collision" "$a_bad_out" "_audit_selftest_collision' is defined as both an alias and a function"
_t_contains "reports duplicate guard identifier" "$a_bad_out" "guard '_ZSH_FIXTURE_DUP_GUARD' used in multiple modules"
_t_contains "reports hardcoded path" "$a_bad_out" "_fixture_bad_a.zsh contains a machine-specific absolute path"
_t_contains "reports failing check count" "$a_bad_out" "FAILING check"

unfunction _audit_test_fixture _audit_test_run
rm -rf "$A_TMP"
