# ============================================================
# Docker Helpers (Ubuntu, Compose v2)
# ============================================================
[[ -n ${_ZSH_TOOL_DOCKER:-} ]] && return
typeset -g _ZSH_TOOL_DOCKER=1

# ---------- guards ----------
_docker_guard() {
  command -v docker >/dev/null 2>&1 || {
    echo "[docker] Docker not installed"
    return 1
  }
}

_compose_guard() {
  for f in compose.yaml compose.yml docker-compose.yml docker-compose.yaml; do
    [[ -f "$f" ]] && return 0
  done
  echo "[docker] No compose file found (compose.yaml/yml, docker-compose.yml/yaml)"
  return 1
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
  [[ -z "$svc" ]] && {
    echo "Usage: dexec <service> [command]"
    echo "  Runs a command inside a compose service (default: sh)."
    return 1
  }
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

dkill-all() {
  _docker_guard || return
  local n
  n=$(docker ps -q 2>/dev/null | wc -l)
  (( n > 0 )) || { echo "[docker] no running containers"; return 0; }
  echo "⚠️  This will kill all $n running container(s)."
  read "?Continue? [y/N]: " ans
  [[ "$ans" == "y" ]] || return
  docker kill $(docker ps -q) 2>/dev/null
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
# dreset-project — rebuilds the project's compose stack. Volume removal is
# OPT-IN (pass --volumes, or set DRESET_VOLUMES=1); always confirms first
# unless --dry-run is passed. DRESET_VOLUMES is compared by value ("1"),
# not by non-emptiness — DRESET_VOLUMES=0 must NOT remove volumes.
dreset-project() {
  _docker_guard || return
  _compose_guard || return

  local do_volumes=0 dry_run=0 arg
  for arg in "$@"; do
    case "$arg" in
      --volumes|-v) do_volumes=1 ;;
      --dry-run|-n) dry_run=1 ;;
    esac
  done
  [[ "${DRESET_VOLUMES:-0}" == 1 ]] && do_volumes=1

  if (( dry_run )); then
    echo "Dry run — would run:"
    if (( do_volumes )); then
      echo "  docker compose down -v"
    else
      echo "  docker compose down"
    fi
    echo "  docker compose build --no-cache"
    echo "  docker compose up -d"
    return 0
  fi

  echo "⚠️  Rebuild: containers will be recreated; $( ((do_volumes)) && echo 'VOLUMES WILL BE REMOVED' || echo 'volumes are kept' )."
  read "?Continue? [y/N]: " ans
  [[ "$ans" == "y" ]] || return

  echo "Resetting project containers, images…"
  if (( do_volumes )); then
    docker compose down -v
  else
    docker compose down
  fi || { echo "[docker] 'compose down' failed; stopping."; return 1; }

  docker compose build --no-cache || { echo "[docker] 'compose build' failed; stopping."; return 1; }
  docker compose up -d || { echo "[docker] 'compose up' failed."; return 1; }
}

# ---------- dev helpers ----------
dsh() {
  _docker_guard || return
  local c
  c=$(docker ps --format "{{.Names}}" | fzf)
  [[ -n "$c" ]] && docker exec -it "$c" sh
}

# ---------- status ----------
dhealth() {
  _docker_guard || return
  echo "Docker version:"
  docker version --format '{{.Server.Version}}'
  echo
  docker system df
}
