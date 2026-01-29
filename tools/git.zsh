# ============================================================
# Git Helpers (Ubuntu, Safe by Default)
# ============================================================

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
gclean-merged() {
  _git_guard && _repo_guard || return
  local base
  base=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  git fetch -p
  git branch --merged "$base" \
    | grep -Ev "(^\*|$base)" \
    | xargs -r git branch -d
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
  git bisect good
}

gbisect-bad() {
  git bisect bad
}

gbisect-reset() {
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
