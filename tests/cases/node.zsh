# ============================================================
# Node lazy-loading regression tests.
# ============================================================
# Covers: wrapper survives a failed nvm load (no more self-unset before
# success), real-executable detection doesn't confuse a shell function
# for availability, ni/nr route through the lazy loader, and a
# standalone (non-nvm) tool still works without nvm ever loading.
# ============================================================

N_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ztests-node-XXXXXX")"
_n_old_pwd="$PWD"
_n_old_path="$PATH"

# ---------- wrapper survives a failed load ----------

unset _ZSH_NVM_LOADED
NVM_DIR="$N_TMP/no-such-nvm-dir"
PATH="/usr/bin:/bin"
node -v >/dev/null 2>&1
_t_eq "node wrapper returns 127 when nvm is unavailable" "$?" "127"
if (( ${+functions[node]} )); then
  _t_pass "node wrapper still defined after a failed load (not self-deleted)"
else
  _t_fail "node wrapper still defined after a failed load (not self-deleted)" "function was removed"
fi

# ---------- real nvm-loaded node/npm via the fake fixture ----------

unset _ZSH_NVM_LOADED
NVM_DIR="$N_TMP/fake-nvm-home"
mkdir -p "$NVM_DIR"
cp "$ZSH_HOME/tests/fixtures/fake-nvm/nvm.sh" "$NVM_DIR/nvm.sh"
export NVM_FAKE_BIN="$N_TMP/fake-nvm-bin"
PATH="/usr/bin:/bin"

out="$(node -v 2>&1)"
_t_contains "node wrapper falls through to nvm-loaded fake node" "$out" "fake-node -v"
out="$(npm -v 2>&1)"
_t_contains "npm wrapper falls through to nvm-loaded fake npm" "$out" "fake-npm -v"

# ---------- ni/nr route through the lazy loader (not bypass it) ----------

unset _ZSH_NVM_LOADED
NVM_DIR="$N_TMP/fake-nvm-home"
PATH="/usr/bin:/bin"
n_proj="$N_TMP/proj"
mkdir -p "$n_proj"
printf '{"name":"x","scripts":{"build":"echo building"}}\n' > "$n_proj/package.json"
cd "$n_proj"
out="$(ni 2>&1)"
_t_contains "ni triggers lazy nvm load and runs fake-npm install" "$out" "fake-npm install"

unset _ZSH_NVM_LOADED
out="$(nr build 2>&1)"
_t_contains "nr triggers lazy nvm load and runs fake-npm run build" "$out" "fake-npm run build"
cd "$_n_old_pwd"

# ---------- standalone tool bypasses nvm entirely ----------

unset _ZSH_NVM_LOADED
NVM_DIR="$N_TMP/no-such-nvm-dir-2"
n_standalone_bin="$N_TMP/standalone-bin"
mkdir -p "$n_standalone_bin"
cat > "$n_standalone_bin/bun" <<'EOF'
#!/usr/bin/env sh
echo "standalone-bun $*"
EOF
chmod +x "$n_standalone_bin/bun"
PATH="$n_standalone_bin:/usr/bin:/bin"
out="$(bun --version 2>&1)"
_t_contains "standalone bun runs without nvm ever loading" "$out" "standalone-bun --version"
_t_eq "standalone bun path did not trigger a (failing) nvm load" "${_ZSH_NVM_LOADED:-0}" "0"

# ---------- _node_guard doesn't false-positive on the wrapper function ----------

unset _ZSH_NVM_LOADED
NVM_DIR="$N_TMP/no-such-nvm-dir-3"
PATH="/usr/bin:/bin"
_t_nok "_node_guard fails when no real node is reachable" _node_guard

PATH="$_n_old_path"
cd "$_n_old_pwd"
rm -rf "$N_TMP"
unset NVM_FAKE_BIN _ZSH_NVM_LOADED
