# ============================================================
# Framework Self-Diagnostics
# ============================================================
# zsh_audit  -> health report for the ~/.zsh framework
# dev_doctor -> alias for zsh_audit
# ============================================================
[[ -n ${_ZSH_TOOL_AUDIT:-} ]] && return
typeset -g _ZSH_TOOL_AUDIT=1

_audit_ok()   { print -P "  %F{green}OK%f    $1"; }
_audit_warn() { print -P "  %F{yellow}WARN%f  $1"; }
_audit_fail() { print -P "  %F{red}FAIL%f  $1"; }

zsh_audit() {
  local root="${ZSH_HOME:-$HOME/.zsh}"
  local rc="$HOME/.zshrc"
  local rc_failures=0

  print -P "%F{cyan}== Zsh framework audit ==%f  ($root)"

  # 1. Syntax check every module
  echo
  echo "[1] Syntax (zsh -n)"
  local f
  for f in "$root"/lib/*.zsh "$root"/tools/*.zsh "$root"/aliases.zsh "$root"/functions.zsh; do
    [[ -f "$f" ]] || continue
    if zsh -n "$f" 2>/dev/null; then
      _audit_ok "${f#$root/}"
    else
      _audit_fail "${f#$root/}  (zsh -n failed)"
      ((rc_failures++))
    fi
  done

  # 2. Duplicate sourcing in ~/.zshrc
  echo
  echo "[2] ~/.zshrc duplication"
  if [[ -f "$rc" ]]; then
    local copies
    copies=$(grep -c "Zsh Developer Framework" "$rc" 2>/dev/null)
    local sources
    sources=$(grep -c 'source "\$ZSH_HOME/lib/errors.zsh"' "$rc" 2>/dev/null)
    if [[ "$sources" -le 1 ]]; then
      _audit_ok "single framework bootstrap ($(wc -l < "$rc") lines)"
    else
      _audit_fail "framework bootstrap appears $sources times -> ~/.zshrc is duplicated"
      ((rc_failures++))
    fi
  else
    _audit_warn "~/.zshrc not found"
  fi

  # 3. Source-once guards present
  echo
  echo "[3] Idempotency guards"
  for f in "$root"/tools/*.zsh "$root"/lib/*.zsh "$root"/aliases.zsh "$root"/functions.zsh; do
    [[ -f "$f" ]] || continue
    if grep -q "&& return" "$f" && grep -q "typeset -g _ZSH" "$f"; then
      _audit_ok "${f#$root/}"
    else
      _audit_warn "${f#$root/}  (no source-once guard)"
    fi
  done

  # 4. Required + optional binaries
  echo
  echo "[4] Tooling"
  local b
  for b in git zsh; do
    command -v "$b" >/dev/null 2>&1 && _audit_ok "$b" || _audit_fail "$b (required, missing)"
  done
  for b in fzf zoxide jq eza bat fd docker node conda code opencode pandoc; do
    command -v "$b" >/dev/null 2>&1 && _audit_ok "$b" || _audit_warn "$b (optional, missing)"
  done

  # 5. Alias/function collisions
  echo
  echo "[5] Alias/function collisions"
  local collisions=0 name
  for name in ${(k)functions}; do
    if [[ -n "${aliases[$name]:-}" ]]; then
      _audit_warn "'$name' is both a function and an alias (alias wins)"
      ((collisions++))
    fi
  done
  ((collisions == 0)) && _audit_ok "none"

  # 6. Startup time
  echo
  echo "[6] Interactive startup time"
  if command -v hyperfine >/dev/null 2>&1; then
    hyperfine --warmup 2 --runs 5 'zsh -i -c exit' 2>/dev/null | grep -E 'Time|mean' | head -1
  else
    zmodload zsh/datetime 2>/dev/null
    local start end
    start=$EPOCHREALTIME
    zsh -i -c exit >/dev/null 2>&1
    end=$EPOCHREALTIME
    printf "  ~%.0f ms (single run; install hyperfine for accurate stats)\n" \
      "$(( (end - start) * 1000 ))"
  fi

  echo
  if ((rc_failures == 0)); then
    print -P "%F{green}== audit passed ==%f"
  else
    print -P "%F{red}== audit found $rc_failures issue(s) ==%f"
    return 1
  fi
}

dev_doctor() { zsh_audit "$@"; }
