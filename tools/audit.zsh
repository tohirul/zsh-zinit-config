# ============================================================
# Framework Self-Diagnostics
# ============================================================
# zsh_audit  -> health report for the ~/.zsh framework (21 checks)
# dev_doctor -> alias for zsh_audit
#
# Exit code: 0 when every FAIL check passes; 1 if any check FAILs.
# WARN items are advisory (non-blocking). Run headless-safe.
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
  echo

  # ----------------------------------------------------------
  # [1] Syntax: every module must pass `zsh -n`
  # ----------------------------------------------------------
  echo "[1] Syntax (zsh -n)"
  local f
  for f in "$root"/lib/*.zsh "$root"/tools/*.zsh "$root"/tools/*/*.zsh "$root"/aliases.zsh "$root"/functions.zsh; do
    [[ -f "$f" ]] || continue
    if zsh -n "$f" 2>/dev/null; then
      _audit_ok "${f#$root/}"
    else
      _audit_fail "${f#$root/}  (zsh -n failed)"
      ((rc_failures++))
    fi
  done

  # ----------------------------------------------------------
  # [2] ~/.zshrc: single bootstrap + mirror integrity
  # ----------------------------------------------------------
  echo
  echo "[2] ~/.zshrc bootstrap"
  if [[ -f "$rc" ]]; then
    local sources
    sources=$(grep -c 'source "\$ZSH_HOME/lib/errors.zsh"' "$rc" 2>/dev/null)
    if [[ "$sources" -le 1 ]]; then
      _audit_ok "single framework bootstrap ($(wc -l < "$rc") lines)"
    else
      _audit_fail "framework bootstrap appears $sources times -> ~/.zshrc is duplicated"
      ((rc_failures++))
    fi
    if cmp -s "$root/zsh_backuprc.zsh" "$rc"; then
      _audit_ok "~/.zshrc in sync with zsh_backuprc.zsh"
    else
      _audit_warn "~/.zshrc differs from zsh_backuprc.zsh (edit the snapshot, then mirror)"
    fi
  else
    _audit_warn "~/.zshrc not found"
  fi

  # ----------------------------------------------------------
  # [3] Idempotency guards (source-once) on every module
  # ----------------------------------------------------------
  echo
  echo "[3] Idempotency guards"
  for f in "$root"/tools/*.zsh "$root"/tools/*/*.zsh "$root"/lib/*.zsh "$root"/aliases.zsh "$root"/functions.zsh; do
    [[ -f "$f" ]] || continue
    if grep -q "&& return" "$f" && grep -q "typeset -g _ZSH" "$f"; then
      _audit_ok "${f#$root/}"
    else
      _audit_warn "${f#$root/}  (no source-once guard)"
    fi
  done

  # ----------------------------------------------------------
  # [4] Required binaries (git, zsh) — FAIL when missing
  # ----------------------------------------------------------
  echo
  echo "[4] Required tooling"
  local b
  for b in git zsh; do
    if command -v "$b" >/dev/null 2>&1; then
      _audit_ok "$b"
    else
      _audit_fail "$b (required, missing)"
      ((rc_failures++))
    fi
  done

  # ----------------------------------------------------------
  # [5] Optional binaries — advisory only
  # ----------------------------------------------------------
  echo
  echo "[5] Optional tooling"
  for b in fzf zoxide jq eza bat fd docker node conda code opencode pandoc gh bun; do
    command -v "$b" >/dev/null 2>&1 && _audit_ok "$b" || _audit_warn "$b (optional, missing)"
  done

  # ----------------------------------------------------------
  # [6] Interactive startup time (<250 ms warm target)
  # ----------------------------------------------------------
  echo
  echo "[6] Interactive startup time"
  local _bench_threshold=250 _bench_hard_fail=500
  if command -v hyperfine >/dev/null 2>&1; then
    local _bench_json="${TMPDIR:-/tmp}/zsh-audit-bench.$$.json"
    hyperfine --warmup 2 --runs 5 --export-json "$_bench_json" 'zsh -i -c exit' 2>/dev/null | grep -E 'Time|mean' | head -1
    if [[ -f "$_bench_json" ]]; then
      local _bench_ms
      _bench_ms=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(round(d["results"][0]["mean"]*1000))' "$_bench_json" 2>/dev/null)
      rm -f "$_bench_json"
      if [[ -n "$_bench_ms" ]]; then
        if (( _bench_ms >= _bench_hard_fail )); then
          _audit_fail "~${_bench_ms} ms mean (hard threshold ${_bench_hard_fail} ms exceeded)"
          ((rc_failures++))
        elif (( _bench_ms >= _bench_threshold )); then
          _audit_warn "~${_bench_ms} ms mean (target <${_bench_threshold} ms)"
        else
          _audit_ok "~${_bench_ms} ms mean"
        fi
      fi
    fi
  else
    # No hard-fail here: a single untimed sample is dominated by
    # first-run compinit cache-build cost (observed ~900ms cold vs
    # ~70ms warm on an identical shell), so it's too noisy to gate CI
    # on. Only the hyperfine branch above (warmed up, averaged over
    # several runs) is reliable enough to hard-fail on.
    zmodload zsh/datetime 2>/dev/null
    local start end
    start=$EPOCHREALTIME
    zsh -i -c exit >/dev/null 2>&1
    end=$EPOCHREALTIME
    local ms
    ms=$(( (end - start) * 1000 ))
    if (( ms < _bench_threshold )); then
      _audit_ok "~$ms ms (single run; install hyperfine for accurate stats)"
    else
      _audit_warn "~$ms ms (target <${_bench_threshold} ms; single run may include cold compinit cache cost; install hyperfine for accurate stats)"
    fi
  fi

  # ----------------------------------------------------------
  # [7] No eager NVM initialization at startup
  # ----------------------------------------------------------
  echo
  echo "[7] No eager NVM"
  local rc_body
  rc_body=$(grep -vE '^[[:space:]]*#' "$rc" 2>/dev/null)
  if print -r -- "$rc_body" | grep -qE 'source.*nvm\.sh|\. .*nvm\.sh|\[ -s "\$NVM_DIR/nvm.sh" \] &&'; then
    _audit_fail "~/.zshrc eagerly sources nvm.sh (nvm must be lazy)"
    ((rc_failures++))
  else
    _audit_ok "nvm is only lazy-loaded on first use"
  fi

  # ----------------------------------------------------------
  # [8] No eager Conda initialization at startup
  # ----------------------------------------------------------
  echo
  echo "[8] No eager Conda"
  if print -r -- "$rc_body" | grep -qE 'conda shell\.zsh hook|anaconda3/etc/profile.d/conda\.sh|>>> conda initialize'; then
    _audit_fail "~/.zshrc eagerly initializes conda"
    ((rc_failures++))
  else
    _audit_ok "conda is only initialized on demand (conda_load)"
  fi

  # ----------------------------------------------------------
  # [9] No network access at startup
  # ----------------------------------------------------------
  echo
  echo "[9] No network at startup"
  if print -r -- "$rc_body" | grep -qE 'curl|wget|git clone|install\.sh|https?://'; then
    _audit_fail "~/.zshrc performs network access at load time"
    ((rc_failures++))
  else
    _audit_ok "no network commands in the startup orchestrator"
  fi

  # ----------------------------------------------------------
  # [10] No global alias destruction
  # ----------------------------------------------------------
  echo
  echo "[10] No unalias -m '*'"
  if print -r -- "$rc_body" | grep -qE '^[[:space:]]*unalias[[:space:]]+-m'; then
    _audit_fail "~/.zshrc destroys aliases globally (unalias -m '*')"
    ((rc_failures++))
  else
    _audit_ok "no global alias destruction"
  fi

  # ----------------------------------------------------------
  # [11] No pipe-to-shell installers executed at startup
  # ----------------------------------------------------------
  echo
  echo "[11] No pipe-to-shell at startup"
  if print -r -- "$rc_body" | grep -qE 'curl[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash)'; then
    _audit_fail "~/.zshrc pipes a download into a shell"
    ((rc_failures++))
  else
    _audit_ok "startup file never pipes downloads into a shell"
  fi
  local _ps
  _ps=$(grep -rlnE 'curl[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash)' "$root"/tools/ 2>/dev/null)
  if [[ -n "$_ps" ]]; then
    _audit_warn "on-demand installer pipe-to-shell present in: $(basename "$_ps") (move to scripts/)"
  fi
  unset _ps

  # ----------------------------------------------------------
  # [12] No duplicate function definitions across modules
  #     (statically scanned — independent of the running shell)
  # ----------------------------------------------------------
  echo
  echo "[12] Function duplication"
  # Same-file re-definition (e.g. an if/else platform fallback both
  # defining the same name) is a common, legitimate pattern — only a
  # definition repeated in a DIFFERENT module is a real duplicate.
  local dups=0 name
  typeset -gA _audit_fname
  for f in "$root"/tools/*.zsh "$root"/tools/*/*.zsh "$root"/lib/*.zsh "$root"/aliases.zsh "$root"/functions.zsh; do
    [[ -f "$f" ]] || continue
    for name in $(grep -oE '^[A-Za-z_][A-Za-z0-9_-]*\(\)' "$f" | sed 's/()//' | sort -u); do
      if (( ${+_audit_fname[$name]} )) && [[ "${_audit_fname[$name]}" != "$f" ]]; then
        _audit_fail "'$name' defined in multiple modules (${_audit_fname[$name]#$root/} and ${f#$root/})"
        ((dups++))
      else
        _audit_fname[$name]="$f"
      fi
    done
  done
  if ((dups == 0)); then
    _audit_ok "no duplicate definitions"
  else
    ((rc_failures += dups))
  fi
  # _audit_fname is reused by [19] below; unset there.

  # ----------------------------------------------------------
  # [13] No machine-specific absolute paths in committed modules
  # ----------------------------------------------------------
  echo
  echo "[13] Portability (no /home/<user> paths)"
  local hits=0
  for f in "$root"/tools/*.zsh "$root"/tools/*/*.zsh "$root"/lib/*.zsh "$root"/aliases.zsh "$root"/functions.zsh; do
    [[ -f "$f" ]] || continue
    if grep -qE '/home/[A-Za-z0-9_.-]+/|/Users/[A-Za-z0-9_.-]+/' "$f"; then
      _audit_fail "${f#$root/} contains a machine-specific absolute path"
      ((hits++))
    fi
  done
  if ((hits == 0)); then
    _audit_ok "all paths are \$HOME-relative or portable"
  else
    ((rc_failures += hits))
  fi

  # ----------------------------------------------------------
  # [14] Compose guard covers every compose filename
  # ----------------------------------------------------------
  echo
  echo "[14] Docker compose filename coverage"
  local df="$root/tools/docker.zsh"
  if [[ -f "$df" ]] && grep -q 'compose.yaml' "$df" && grep -q 'compose.yml' "$df"; then
    _audit_ok "_compose_guard accepts compose.yaml / compose.yml"
  else
    _audit_fail "docker.zsh _compose_guard misses compose.yaml and/or compose.yml"
    ((rc_failures++))
  fi

  # ----------------------------------------------------------
  # [15] jq used atomically (--arg/--argjson, no raw interpolation)
  # ----------------------------------------------------------
  echo
  echo "[15] jq injection safety"
  local vf="$root/tools/vscode.zsh"
  if [[ -f "$vf" ]] && grep -q -- '--argjson' "$vf" && grep -q -- '--arg ' "$vf"; then
    _audit_ok "vscode.zsh passes values via --arg/--argjson"
  else
    _audit_warn "vscode.zsh does not use --arg/--argjson (check code_settings_set)"
  fi

  # ----------------------------------------------------------
  # [16] Machine-local config hook + example present
  # ----------------------------------------------------------
  echo
  echo "[16] local.env.zsh / local.zsh override hooks"
  if [[ -f "$rc" ]] && grep -q 'local.env.zsh' "$rc"; then
    _audit_ok "orchestrator sources \$ZSH_HOME/local.env.zsh (early) when present"
  else
    _audit_fail "orchestrator has no early local.env.zsh override hook"
    ((rc_failures++))
  fi
  if [[ -f "$rc" ]] && grep -q 'local.zsh"' "$rc"; then
    _audit_ok "orchestrator sources \$ZSH_HOME/local.zsh (late) when present"
  else
    _audit_fail "orchestrator has no late local.zsh override hook"
    ((rc_failures++))
  fi
  if [[ -f "$root/local.env.zsh.example" ]]; then
    _audit_ok "local.env.zsh.example ships as the reference"
  else
    _audit_warn "local.env.zsh.example missing"
  fi
  if [[ -f "$root/local.zsh.example" ]]; then
    _audit_ok "local.zsh.example ships as the reference"
  else
    _audit_warn "local.zsh.example missing"
  fi

  # ----------------------------------------------------------
  # [17] Destructive operations are gated (opt-in)
  # ----------------------------------------------------------
  echo
  echo "[17] Destructive ops are opt-in"
  local gated=1
  if [[ -f "$root/functions.zsh" ]] && ! grep -q -- '--force' "$root/functions.zsh"; then
    _audit_fail "functions.zsh dev_clean is not gated behind --force"
    gated=0
  fi
  if [[ -f "$df" ]] && ! grep -q 'Continue?' "$df"; then
    _audit_fail "docker.zsh destructive commands lack confirmation prompts"
    gated=0
  fi
  if (( gated )); then
    _audit_ok "dev_clean requires --force; docker destructive ops confirm"
  else
    ((rc_failures++))
  fi

  # ----------------------------------------------------------
  # [18] No duplicate alias definitions
  # ----------------------------------------------------------
  echo
  echo "[18] Alias duplication"
  # Same-file re-definition (if/else fallback, e.g. eza vs ls) is
  # legitimate; only a different-module duplicate is flagged.
  local adups=0 aname
  typeset -gA _audit_alias
  for f in "$root"/aliases.zsh "$root"/tools/*.zsh "$root"/tools/*/*.zsh; do
    [[ -f "$f" ]] || continue
    for aname in $(grep -oE '^[[:space:]]*alias[[:space:]]+[A-Za-z_][A-Za-z0-9_-]*=' "$f" | sed -E 's/^[[:space:]]*alias[[:space:]]+//; s/=$//' | sort -u); do
      if (( ${+_audit_alias[$aname]} )) && [[ "${_audit_alias[$aname]}" != "$f" ]]; then
        _audit_fail "alias '$aname' defined in multiple modules (${_audit_alias[$aname]#$root/} and ${f#$root/})"
        ((adups++))
      else
        _audit_alias[$aname]="$f"
      fi
    done
  done
  if ((adups == 0)); then
    _audit_ok "no duplicate alias definitions"
  else
    ((rc_failures += adups))
  fi

  # ----------------------------------------------------------
  # [19] No alias/function name collisions
  # ----------------------------------------------------------
  echo
  echo "[19] Alias/function collisions"
  local collisions=0 cname
  for cname in "${(@k)_audit_alias}"; do
    if (( ${+_audit_fname[$cname]} )); then
      _audit_fail "'$cname' is defined as both an alias and a function"
      ((collisions++))
    fi
  done
  if ((collisions == 0)); then
    _audit_ok "no alias/function name collisions"
  else
    ((rc_failures += collisions))
  fi
  unset _audit_fname _audit_alias

  # ----------------------------------------------------------
  # [20] No duplicate source-once guard identifiers
  # ----------------------------------------------------------
  echo
  echo "[20] Duplicate guard identifiers"
  local gdups=0 gname
  typeset -A _audit_guard
  for f in "$root"/tools/*.zsh "$root"/tools/*/*.zsh "$root"/lib/*.zsh "$root"/aliases.zsh "$root"/functions.zsh; do
    [[ -f "$f" ]] || continue
    for gname in $(grep -oE 'typeset -g (_ZSH[A-Za-z0-9_]*)=1' "$f" | awk '{print $3}' | sed 's/=1$//'); do
      if (( ${+_audit_guard[$gname]} )); then
        _audit_fail "guard '$gname' used in multiple modules (${_audit_guard[$gname]} and ${f#$root/})"
        ((gdups++))
      else
        _audit_guard[$gname]="${f#$root/}"
      fi
    done
  done
  if ((gdups == 0)); then
    _audit_ok "every source-once guard identifier is unique"
  else
    ((rc_failures += gdups))
  fi
  unset _audit_guard

  # ----------------------------------------------------------
  # [21] Azkaban vault variable consistency (advisory)
  # ----------------------------------------------------------
  echo
  echo "[21] Azkaban vault variable consistency"
  if [[ -n "${AZKABAN_VAULT:-}" && -n "${AZKABAN_DIR:-}" && "${AZKABAN_VAULT}" != "${AZKABAN_DIR}" ]]; then
    _audit_warn "AZKABAN_VAULT ($AZKABAN_VAULT) and AZKABAN_DIR ($AZKABAN_DIR) differ — Graphify defaults AZKABAN_DIR from AZKABAN_VAULT unless overridden explicitly"
  else
    _audit_ok "AZKABAN_VAULT/AZKABAN_DIR are consistent"
  fi

  # ----------------------------------------------------------
  echo
  if ((rc_failures == 0)); then
    print -P "%F{green}== audit passed (21 checks) ==%f"
  else
    print -P "%F{red}== audit found $rc_failures FAILING check(s) ==%f"
    return 1
  fi
}

dev_doctor() { zsh_audit "$@"; }
