# ============================================================
# NVIDIA PRIME Pro Launchers (Ubuntu Hybrid GPU)
# ============================================================
# Offload rendering to the discrete NVIDIA GPU per-command.
# All launchers are no-ops (with a clear error) when NVIDIA is unavailable.
# ============================================================
[[ -n ${_ZSH_TOOL_GPU:-} ]] && return
typeset -g _ZSH_TOOL_GPU=1

# ---------- detection ----------
_prime_has_nvidia() {
  command -v nvidia-smi >/dev/null 2>&1 || return 1
  nvidia-smi >/dev/null 2>&1
}

_prime_session() {
  echo "${XDG_SESSION_TYPE:-unknown}"
}

# ---------- PRIME environment ----------
# Runs a command with the NVIDIA PRIME offload environment set for THAT
# command only. Never exports into the caller's shell (no env leaks).
_prime_env() {
  env \
    __NV_PRIME_RENDER_OFFLOAD=1 \
    __GLX_VENDOR_LIBRARY_NAME=nvidia \
    __VK_LAYER_NV_optimus=NVIDIA_only \
    LIBVA_DRIVER_NAME=nvidia \
    VDPAU_DRIVER=nvidia \
    "$@"
}

# ---------- info ----------
prime-info() {
  echo "========================================"
  echo " PRIME GPU STATUS"
  echo "========================================"
  echo "Session: $(_prime_session)"
  echo "Prime Mode: $(sudo prime-select query 2>/dev/null || echo unknown)"
  echo

  if _prime_has_nvidia; then
    echo "NVIDIA Driver: OK"
    nvidia-smi --query-gpu=name,driver_version,temperature.gpu,memory.used,memory.total \
      --format=csv,noheader
  else
    echo "NVIDIA Driver: FAILED"
  fi

  echo
  echo "Default Renderer:"
  glxinfo 2>/dev/null | grep "OpenGL renderer" || true
  echo "========================================"
}

# ---------- generic launchers ----------
prun() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: prun <command> [args]"
    return 1
  fi

  if ! _prime_has_nvidia; then
    echo "ERROR: NVIDIA driver not active."
    echo "Run: nvidia-smi"
    return 1
  fi

  _prime_env "$@"
}

prun-gl() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: prun-gl <command> [args]"
    return 1
  fi

  if ! _prime_has_nvidia; then
    echo "ERROR: NVIDIA driver not active."
    return 1
  fi

  _prime_env "$@" --use-gl=desktop
}

prun-vk() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: prun-vk <command> [args]"
    return 1
  fi

  if ! _prime_has_nvidia; then
    echo "ERROR: NVIDIA driver not active."
    return 1
  fi

  _prime_env "$@" \
    --enable-features=Vulkan \
    --use-vulkan
}

# ---------- app launchers ----------
codegpu() {
  if ! nvidia-smi >/dev/null 2>&1; then
    echo "ERROR: NVIDIA driver unavailable"
    return 1
  fi

  env \
    __NV_PRIME_RENDER_OFFLOAD=1 \
    __GLX_VENDOR_LIBRARY_NAME=nvidia \
    __VK_LAYER_NV_optimus=NVIDIA_only \
    code "$@"
}

codevk() {
  if ! _prime_has_nvidia; then
    echo "ERROR: NVIDIA unavailable."
    return 1
  fi

  _prime_env code "$@" \
    --enable-features=Vulkan \
    --ignore-gpu-blocklist \
    --disable-software-rasterizer
}

chromegpu() {
  if ! _prime_has_nvidia; then
    echo "ERROR: NVIDIA unavailable."
    return 1
  fi

  _prime_env google-chrome-stable "$@" \
    --ignore-gpu-blocklist \
    --enable-gpu-rasterization \
    --enable-zero-copy
}

chromevk() {
  if ! _prime_has_nvidia; then
    echo "ERROR: NVIDIA unavailable."
    return 1
  fi

  _prime_env google-chrome-stable "$@" \
    --ignore-gpu-blocklist \
    --enable-gpu-rasterization \
    --enable-zero-copy \
    --enable-features=Vulkan \
    --use-vulkan
}

# ---------- monitoring ----------
prime-procs() {
  nvidia-smi
}

prime-top() {
  nvtop
}

prime-test() {
  _prime_env glxinfo | grep "OpenGL renderer"
}
