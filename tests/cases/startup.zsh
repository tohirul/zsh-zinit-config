# ============================================================
# Startup contract regression tests.
# ============================================================
# Unlike the other test cases, this one deliberately DOES source
# zsh_backuprc.zsh — but in an isolated child `zsh -f`, with a fake
# HOME/ZINIT_HOME and curl/wget/git-clone traps on PATH, so a
# regression that reintroduces network access or an eager plugin
# clone at startup fails loudly instead of only showing up on a
# fresh machine.
# ============================================================

S_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ztests-startup-XXXXXX")"
s_fake_home="$S_TMP/home"
s_zinit_home="$S_TMP/zinit-home/zinit.git"
s_net_log="$S_TMP/network-calls.log"
s_real_git="$(command -v git)"

mkdir -p "$s_fake_home" "$s_zinit_home"

# Stub zinit: if the plugin-readiness gate in zsh_backuprc.zsh is broken
# and it tries to load a plugin anyway, this records the call instead of
# actually cloning anything.
cat > "$s_zinit_home/zinit.zsh" <<'EOF'
zinit() { echo "zinit-call: $*" >> "$ZSH_TEST_ZINIT_LOG"; }
EOF

s_out="$S_TMP/startup.out"
env -i \
  HOME="$s_fake_home" \
  PATH="$ZSH_HOME/tests/fixtures/fake-bin:/usr/bin:/bin" \
  ZSH_HOME="$ZSH_HOME" \
  ZINIT_HOME="$s_zinit_home" \
  ZSH_TEST_NETWORK_LOG="$s_net_log" \
  ZSH_TEST_REAL_GIT="$s_real_git" \
  ZSH_TEST_ZINIT_LOG="$S_TMP/zinit-calls.log" \
  zsh -f -c 'source "$ZSH_HOME/zsh_backuprc.zsh" && echo STARTUP_OK' \
  > "$s_out" 2>&1
s_rc=$?

_t_eq "startup exits 0 with no zinit/plugins installed" "$s_rc" "0"
_t_file_contains "startup completes (STARTUP_OK marker)" "$s_out" "STARTUP_OK"
_t_file_absent "no curl/wget/git-clone invoked during startup" "$s_net_log"
_t_file_absent "no plugin was loaded via zinit (all missing, all gated)" "$S_TMP/zinit-calls.log"

rm -rf "$S_TMP"
