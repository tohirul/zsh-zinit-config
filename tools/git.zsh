# ============================================================
# Git Helpers (Ubuntu, Safe by Default)
# ============================================================
[[ -n ${_ZSH_TOOL_GIT:-} ]] && return
typeset -g _ZSH_TOOL_GIT=1

# ---------- guards ----------
_git_guard() {
  command -v git >/dev/null 2>&1 || {
    echo "[git] Git not installed"
    return 1
  }
}

_repo_guard() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "[git] Not a git repository"
    return 1
  }
}

# ---------- status ----------
gs() {
  _git_guard && _repo_guard || return
  git status -sb
}

gdiff() {
  _git_guard && _repo_guard || return
  git diff "$@"
}

glog() {
  _git_guard && _repo_guard || return
  git log --oneline --graph --decorate --all --max-count=30
}

# ---------- branches ----------
gbr() {
  _git_guard && _repo_guard || return
  git branch --sort=-committerdate
}

gco() {
  _git_guard && _repo_guard || return
  git checkout "$@"
}

gcb() {
  _git_guard && _repo_guard || return
  git checkout -b "$1"
}

# ---------- safe cleanup ----------
# gclean-merged — lists branches already merged into the default branch.
# Safe by default: only prints candidates. Pass -f/--prune to actually delete
# (git branch -d refuses to delete unmerged or checked-out branches anyway).
gclean-merged() {
  _git_guard && _repo_guard || return

  local base="${1:-}"
  if [[ -z "$base" || "$base" == "-f" || "$base" == "--prune" ]]; then
    base=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null)
    base="${base#origin/}"
    [[ -z "$base" || "$base" == "HEAD" ]] && base=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  fi
  [[ -n "$base" && "$base" != "HEAD" ]] || {
    echo "[git] cannot determine the default branch (pass one: gclean-merged main)"
    return 1
  }

  local prune=0
  [[ "$1" == "-f" || "$1" == "--prune" ]] && prune=1

  git fetch -p 2>/dev/null || true

  local merged
  merged=$(git branch --merged "$base" 2>/dev/null \
    | sed 's/^[* ] *//' \
    | grep -Ev "^(HEAD|${base}|dev|develop|staging|main|master)$" \
    | grep -v '^$' || true)

  if [[ -z "$merged" ]]; then
    echo "[git] no merged branches to clean (base: $base)"
    return 0
  fi

  echo "Merged branches (base: $base):"
  echo "$merged" | sed 's/^/  - /'
  echo "Current branch: $(git rev-parse --abbrev-ref HEAD)"

  if (( ! prune )); then
    echo "[git] Dry-run: re-run with -f (or --prune) to delete."
    return 0
  fi

  echo "$merged" | while read -r b; do
    [[ -n "$b" ]] && git branch -d "$b"
  done
}
# ---------- stash ----------
gstash() {
  _git_guard && _repo_guard || return
  git stash push -m "${1:-wip}"
}

gstash-pop() {
  _git_guard && _repo_guard || return
  git stash pop
}

# ---------- commits ----------
gcm() {
  _git_guard && _repo_guard || return
  git commit -m "$*"
}

gca() {
  _git_guard && _repo_guard || return
  git commit --amend
}

# ---------- sync ----------
gp() {
  _git_guard && _repo_guard || return
  git push
}

gpf() {
  _git_guard && _repo_guard || return
  echo "⚠️  Safe force-push (with lease)"
  git push --force-with-lease
}

gl() {
  _git_guard && _repo_guard || return
  git pull --rebase
}

# ---------- history & debugging ----------
gblame() {
  _git_guard && _repo_guard || return
  git blame "$@"
}

gbisect-start() {
  _git_guard && _repo_guard || return
  git bisect start
}

gbisect-good() {
  _git_guard && _repo_guard || return
  git bisect good
}

gbisect-bad() {
  _git_guard && _repo_guard || return
  git bisect bad
}

gbisect-reset() {
  _git_guard && _repo_guard || return
  git bisect reset
}

# ---------- repo health ----------
ghealth() {
  _git_guard && _repo_guard || return
  echo "🔍 Repo health check"
  git fsck --no-progress
  echo
  git count-objects -vH
}

# ---------- large repo helpers ----------
gfind-big() {
  _git_guard && _repo_guard || return
  git rev-list --objects --all \
    | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' \
    | sed -n 's/^blob //p' \
    | sort -k2nr \
    | head -n 10
}

# ---------- GitHub CLI ----------
ghpr() {
  command -v gh >/dev/null 2>&1 || {
    echo "[git] gh not installed"
    return 1
  }
  gh pr view --web
}

ghrepo() {
  command -v gh >/dev/null 2>&1 || {
    echo "[git] gh not installed"
    return 1
  }
  gh repo view --web
}

# ---------- interactive ----------
gco-fzf() {
  _git_guard && _repo_guard || return
  local branch
  branch=$(git branch --all | sed 's/^..//' | fzf)
  [[ -n "$branch" ]] && git checkout "${branch#remotes/}"
}
