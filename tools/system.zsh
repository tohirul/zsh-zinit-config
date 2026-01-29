# ============================================================
# System Helpers (Ubuntu, Safe, Manual)
# ============================================================

# ---------- guards ----------
_is_linux() {
  [[ "$(uname -s)" == "Linux" ]]
}

_is_ubuntu() {
  [[ -f /etc/os-release ]] && grep -qi ubuntu /etc/os-release
}

_root_warn() {
  [[ "$EUID" -eq 0 ]] && {
    echo "[system] Warning: running as root"
  }
}

# ---------- system info ----------
sys_info() {
  _is_linux || return

  echo "🖥️  System"
  lsb_release -d 2>/dev/null || uname -a
  echo
  echo "🧠 CPU"
  lscpu | grep -E 'Model name|Socket|Thread|Core'
  echo
  echo "💾 Memory"
  free -h
}

# ---------- disk ----------
disk_usage() {
  df -hT | grep -Ev 'tmpfs|loop'
}

disk_big() {
  sudo du -ahx / | sort -rh | head -n 20
}

disk_here() {
  du -sh ./*
}

# ---------- memory / cpu ----------
mem_top() {
  ps aux --sort=-%mem | head -n 15
}

cpu_top() {
  ps aux --sort=-%cpu | head -n 15
}

# ---------- ports ----------
port_used() {
  [[ -z "$1" ]] && {
    echo "Usage: port_used <port>"
    return 1
  }

  sudo lsof -i :"$1"
}

port_kill() {
  [[ -z "$1" ]] && {
    echo "Usage: port_kill <port>"
    return 1
  }

  sudo fuser -k "$1"/tcp
}

# ---------- networking ----------
net_listen() {
  ss -tulpn
}

# ---------- processes ----------
proc_find() {
  [[ -z "$1" ]] && {
    echo "Usage: proc_find <name>"
    return 1
  }

  ps aux | grep -i "$1" | grep -v grep
}

proc_kill() {
  [[ -z "$1" ]] && {
    echo "Usage: proc_kill <pid>"
    return 1
  }

  kill "$1"
}

# ---------- packages (apt) ----------
apt_update() {
  _is_ubuntu || return
  sudo apt update
}

apt_upgrade() {
  _is_ubuntu || return
  sudo apt upgrade
}

apt_search() {
  _is_ubuntu || return
  apt search "$1"
}

apt_install() {
  _is_ubuntu || return
  sudo apt install "$@"
}

apt_remove() {
  _is_ubuntu || return
  sudo apt remove "$@"
}

apt_cleanup() {
  _is_ubuntu || return
  sudo apt autoremove
  sudo apt autoclean
}

# ---------- dev diagnostics ----------
dev_ports() {
  echo "Common dev ports in use:"
  ss -tulpn | grep -E ':(3000|3001|4000|5000|5173|8000|8080|9229)'
}

dev_health() {
  echo "🔎 Dev environment health"
  echo
  echo "Node: $(command -v node >/dev/null && node -v || echo missing)"
  echo "Python: $(command -v python >/dev/null && python --version || echo missing)"
  echo "Docker: $(command -v docker >/dev/null && docker --version || echo missing)"
  echo "Git: $(command -v git >/dev/null && git --version || echo missing)"
}
