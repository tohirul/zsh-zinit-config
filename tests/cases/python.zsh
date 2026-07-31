# ============================================================
# Conda/Python correctness regression tests.
# ============================================================
# Covers: conda readiness uses shell-function existence (not a bare
# executable on PATH), CONDA_ROOT override, base-env install refusal,
# and .conda-env content validation.
# ============================================================

P_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ztests-python-XXXXXX")"
_p_old_pwd="$PWD"
_p_old_conda_default_env="${CONDA_DEFAULT_ENV:-}"
_p_old_py_allow_base="${PY_ALLOW_BASE:-}"

# ---------- _conda_loaded: function-existence, not command -v ----------

unfunction conda 2>/dev/null
if _conda_loaded; then
  _t_fail "_conda_loaded is false when no conda shell function is defined" "returned true (even though a real conda binary may be on PATH)"
else
  _t_pass "_conda_loaded is false when no conda shell function is defined"
fi

conda() { :; }
_t_ok "_conda_loaded is true once a conda shell function exists" _conda_loaded
unfunction conda

# ---------- _conda_root: CONDA_ROOT override wins ----------

p_fake_root="$P_TMP/fake-conda"
mkdir -p "$p_fake_root/bin"
: > "$p_fake_root/bin/conda"
chmod +x "$p_fake_root/bin/conda"
out="$(CONDA_ROOT="$p_fake_root" _conda_root)"
_t_eq "_conda_root prefers \$CONDA_ROOT over built-in search paths" "$out" "$p_fake_root"

# ---------- _py_require_active_env: base-env refusal ----------

unset CONDA_DEFAULT_ENV
_t_nok "_py_require_active_env fails with no active env" _py_require_active_env

CONDA_DEFAULT_ENV=base
unset PY_ALLOW_BASE
_t_nok "_py_require_active_env refuses base by default" _py_require_active_env

PY_ALLOW_BASE=1
_t_ok "_py_require_active_env allows base when PY_ALLOW_BASE=1" _py_require_active_env
unset PY_ALLOW_BASE

CONDA_DEFAULT_ENV=myproject
_t_ok "_py_require_active_env allows a normal named env" _py_require_active_env

# ---------- .conda-env validation ----------

p_proj="$P_TMP/proj"
mkdir -p "$p_proj"
cd "$p_proj"

printf 'myenv\n' > .conda-env
out="$(py_use_here 2>&1)"
if [[ "$out" == *"invalid characters"* || "$out" == *"exactly one line"* ]]; then
  _t_fail "py_use_here accepts a normal single-line env name" "$out"
else
  _t_pass "py_use_here accepts a normal single-line env name (passes validation)"
fi

printf 'line-one\nline-two\n' > .conda-env
out="$(py_use_here 2>&1)"
_t_contains "py_use_here rejects a multi-line .conda-env" "$out" "exactly one line"

: > .conda-env
out="$(py_use_here 2>&1)"
_t_contains "py_use_here rejects an empty .conda-env" "$out" "empty"

printf 'my; rm -rf /\n' > .conda-env
out="$(py_use_here 2>&1)"
_t_contains "py_use_here rejects .conda-env with shell metacharacters" "$out" "invalid characters"

cd "$_p_old_pwd"

# ---------- restore ----------

if [[ -n "$_p_old_conda_default_env" ]]; then
  CONDA_DEFAULT_ENV="$_p_old_conda_default_env"
else
  unset CONDA_DEFAULT_ENV
fi
if [[ -n "$_p_old_py_allow_base" ]]; then
  PY_ALLOW_BASE="$_p_old_py_allow_base"
else
  unset PY_ALLOW_BASE
fi

rm -rf "$P_TMP"
