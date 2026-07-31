# ============================================================
# Test helpers — pure zsh, no external test framework.
# ============================================================
# Assertion vocabulary:
#   _t_ok <desc> <cmd...>          cmd exits 0
#   _t_nok <desc> <cmd...>         cmd exits non-zero
#   _t_eq <desc> <actual> <expected>
#   _t_contains <desc> <hay> <needle>
#   _t_file_contains <desc> <file> <needle>
#   _t_file_absent <desc> <file>
#   _t_count <desc> <pattern> <file> <expected-count>
#   _t_summary                     print totals; returns 1 on any failure
# ============================================================
[[ -n ${_ZSH_TESTS_HELPER:-} ]] && return
typeset -g _ZSH_TESTS_HELPER=1

typeset -g _T_PASS=0
typeset -g _T_FAIL=0
typeset -ga _T_FAILURES=()

_t_pass() {
  _T_PASS=$((_T_PASS + 1))
  print -r -- "ok   $1"
}

_t_fail() {
  _T_FAIL=$((_T_FAIL + 1))
  _T_FAILURES+=("$1 :: $2")
  print -r -- "FAIL $1 :: $2"
}

_t_ok() {
  local desc="$1"
  shift
  "$@" >/dev/null 2>&1
  local rc=$?
  if (( rc == 0 )); then
    _t_pass "$desc"
  else
    _t_fail "$desc" "expected success, got exit $rc"
  fi
}

_t_nok() {
  local desc="$1"
  shift
  "$@" >/dev/null 2>&1
  local rc=$?
  if (( rc != 0 )); then
    _t_pass "$desc"
  else
    _t_fail "$desc" "expected failure, got exit 0"
  fi
}

_t_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    _t_pass "$desc"
  else
    _t_fail "$desc" "expected [$expected], got [$actual]"
  fi
}

_t_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    _t_pass "$desc"
  else
    _t_fail "$desc" "expected to contain [$needle]"
  fi
}

_t_file_contains() {
  local desc="$1" file="$2" needle="$3"
  if [[ -f "$file" ]] && grep -qF -- "$needle" "$file"; then
    _t_pass "$desc"
  else
    _t_fail "$desc" "file [$file] missing [$needle]"
  fi
}

_t_file_absent() {
  local desc="$1" file="$2"
  if [[ ! -e "$file" ]]; then
    _t_pass "$desc"
  else
    _t_fail "$desc" "expected absent: $file"
  fi
}

_t_count() {
  local desc="$1" pattern="$2" file="$3" expected="$4" n
  if [[ -f "$file" ]]; then
    n="$(grep -cF -- "$pattern" "$file" 2>/dev/null)"
    n="${n:-0}"
  else
    n="0"
  fi
  _t_eq "$desc" "$n" "$expected"
}

_t_summary() {
  print -r -- ""
  print -r -- "== ${_T_PASS} passed, ${_T_FAIL} failed =="
  if (( _T_FAIL > 0 )); then
    local f
    for f in "${_T_FAILURES[@]}"; do
      print -r -- "  - $f"
    done
    return 1
  fi
  return 0
}
