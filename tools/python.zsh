# ============================================================
# Python / Conda Helpers (Ubuntu, Manual, Project-Scoped)
# ============================================================

# ---------- internal helpers ----------
_conda_root() {
  for p in "$HOME/anaconda3" "$HOME/miniconda3" "/opt/conda"; do
    if [[ -x "$p/bin/conda" ]]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

_conda_loaded() {
  command -v conda >/dev/null 2>&1
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

  conda_load || return
  conda activate "$(cat .conda-env)"
}

# ---------- packages ----------
py_install() {
  conda_load || return
  conda install "$@"
}

py_pip_install() {
  conda_load || return
  pip install "$@"
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
