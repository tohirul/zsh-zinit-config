# ============================================================
# Python / Conda Helpers (Ubuntu, Manual, Project-Scoped)
# ============================================================
[[ -n ${_ZSH_TOOL_PYTHON:-} ]] && return
typeset -g _ZSH_TOOL_PYTHON=1

# ---------- internal helpers ----------
_conda_root() {
  local p
  for p in "$CONDA_ROOT" "$HOME/anaconda3" "$HOME/miniconda3" "/opt/conda"; do
    [[ -n "$p" ]] || continue
    if [[ -x "$p/bin/conda" ]]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

# Conda's own shell integration (etc/profile.d/conda.sh) defines `conda`
# as a shell FUNCTION so `conda activate` can mutate the current shell —
# a bare executable on PATH with no shell hook loaded can't activate
# anything, so function-existence (not `command -v`) is the real signal.
_conda_loaded() {
  (( ${+functions[conda]} ))
}

# ---------- lazy loader ----------
conda_load() {
  if _conda_loaded; then
    return 0
  fi

  local root
  root="$(_conda_root)" || {
    echo "[python] Conda installation not found"
    return 1
  }

  # shellcheck disable=SC1090
  source "$root/etc/profile.d/conda.sh"
}

# ---------- activation ----------
py_activate() {
  [[ -z "$1" ]] && {
    echo "Usage: py_activate <env-name>"
    return 1
  }

  conda_load || return
  conda activate "$1"
}

py_deactivate() {
  _conda_loaded || return
  conda deactivate
}

# ---------- environments ----------
py_envs() {
  conda_load || return
  conda env list
}

py_create() {
  [[ -z "$1" ]] && {
    echo "Usage: py_create <env-name> [python-version]"
    return 1
  }

  local name="$1"
  local version="${2:-3.11}"

  conda_load || return
  conda create -n "$name" python="$version"
}

py_remove() {
  [[ -z "$1" ]] && {
    echo "Usage: py_remove <env-name>"
    return 1
  }

  conda_load || return

  echo "⚠️  Removing conda environment: $1"
  read "?Continue? [y/N]: " ans
  [[ "$ans" == "y" ]] || return

  conda env remove -n "$1"
}

# ---------- project helpers ----------
py_mark_env() {
  [[ -z "$CONDA_DEFAULT_ENV" ]] && {
    echo "[python] No active conda environment"
    return 1
  }

  echo "$CONDA_DEFAULT_ENV" > .conda-env
  echo "[python] Project linked to env: $CONDA_DEFAULT_ENV"
}

py_use_here() {
  [[ -f .conda-env ]] || {
    echo "[python] .conda-env file not found"
    return 1
  }

  local env_name
  env_name="$(<.conda-env)"

  # Must be exactly one line, non-empty, and look like a conda env name
  # (no shell metacharacters) — .conda-env can be hand-edited or written
  # by another tool, so its content isn't trusted blindly before being
  # handed to `conda activate`.
  if [[ "$env_name" == *$'\n'* ]]; then
    echo "[python] .conda-env must contain exactly one line"
    return 1
  fi
  if [[ -z "$env_name" ]]; then
    echo "[python] .conda-env is empty"
    return 1
  fi
  if [[ ! "$env_name" =~ ^[A-Za-z0-9._/-]+$ ]]; then
    echo "[python] .conda-env contains invalid characters: $env_name"
    return 1
  fi

  conda_load || return
  conda activate "$env_name"
}

# ---------- packages ----------

# Refuse to install into an unspecified or base environment by default —
# `conda install`/`pip install` with no active env silently lands in
# base, which is easy to do by accident and hard to clean up.
_py_require_active_env() {
  if [[ -z "${CONDA_DEFAULT_ENV:-}" ]]; then
    echo "[python] No active Conda environment. Run 'py_activate <env>' first." >&2
    return 1
  fi
  if [[ "$CONDA_DEFAULT_ENV" == base && "${PY_ALLOW_BASE:-0}" != 1 ]]; then
    echo "[python] Refusing to install into 'base'." >&2
    echo "[python] Set PY_ALLOW_BASE=1 if this is intentional." >&2
    return 1
  fi
  return 0
}

py_install() {
  conda_load || return
  _py_require_active_env || return 1
  conda install "$@"
}

py_pip_install() {
  conda_load || return
  _py_require_active_env || return 1
  python -m pip install "$@"
}

py_freeze() {
  conda_load || return
  conda env export --from-history
}

# ---------- diagnostics ----------
py_info() {
  _conda_loaded || return
  echo "Python: $(python --version)"
  echo "Env: $CONDA_DEFAULT_ENV"
  which python
}

py_health() {
  conda_load || return
  conda info
}
