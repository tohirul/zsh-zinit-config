# ============================================================
# Docker Helpers (Ubuntu, Compose v2)
# ============================================================

# ---------- guards ----------
_docker_guard() {
  command -v docker >/dev/null 2>&1 || {
    echo "[docker] Docker not installed"
    return 1
  }
}

_compose_guard() {
  [[ -f docker-compose.yml || -f docker-compose.yaml ]] || {
    echo "[docker] No docker-compose file found"
    return 1
  }
}

# ---------- basic ----------
dps() {
  _docker_guard || return
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

dpsa() {
  _docker_guard || return
  docker ps -a
}

di() {
  _docker_guard || return
  docker images
}

# ---------- compose ----------
dup() {
  _docker_guard || return
  _compose_guard || return
  docker compose up "$@"
}

dup-d() {
  _docker_guard || return
  _compose_guard || return
  docker compose up -d "$@"
}

ddown() {
  _docker_guard || return
  _compose_guard || return
  docker compose down
}

drestart() {
  _docker_guard || return
  _compose_guard || return
  docker compose restart "$@"
}

dlogs() {
  _docker_guard || return
  _compose_guard || return
  docker compose logs -f --tail=100 "$@"
}

dbuild() {
  _docker_guard || return
  _compose_guard || return
  docker compose build "$@"
}

dexec() {
  _docker_guard || return
  _compose_guard || return
  local svc="$1"
  shift
  docker compose exec "$svc" "${@:-sh}"
}

# ---------- cleanup (SAFE) ----------
dclean-containers() {
  _docker_guard || return
  docker container prune
}

dclean-images() {
  _docker_guard || return
  docker image prune
}

dclean-volumes() {
  _docker_guard || return
  docker volume prune
}

dclean-networks() {
  _docker_guard || return
  docker network prune
}

# ---------- aggressive cleanup (explicit) ----------
dclean-all() {
  _docker_guard || return
  echo "⚠️  This will remove ALL unused Docker data."
  read "?Continue? [y/N]: " ans
  [[ "$ans" == "y" ]] || return
  docker system prune -af --volumes
}

# ---------- inspection ----------
dinspect() {
  _docker_guard || return
  docker inspect "$1" | jq
}

dsize() {
  _docker_guard || return
  docker system df
}

# ---------- project utilities ----------
dreset-project() {
  _docker_guard || return
  _compose_guard || return
  echo "Resetting project containers, volumes, and images…"
  docker compose down -v
  docker compose build --no-cache
  docker compose up -d
}

# ---------- dev helpers ----------
dsh() {
  _docker_guard || return
  local c
  c=$(docker ps --format "{{.Names}}" | fzf)
  [[ -n "$c" ]] && docker exec -it "$c" sh
}

dkill-all() {
  _docker_guard || return
  docker kill $(docker ps -q) 2>/dev/null
}

# ---------- status ----------
dhealth() {
  _docker_guard || return
  echo "Docker version:"
  docker version --format '{{.Server.Version}}'
  echo
  docker system df
}
