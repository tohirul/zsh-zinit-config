# ============================================================
# Regression: every public command/alias survives the splits.
# ============================================================

typeset -a missing=()

_obs_cmds=(
  obs-home obs-open obs-today obs-capture obs-task obs-note obs-find
  obs-project-connect obs-project-bind obs-project-log obs-project-task
  obs-project-snapshot obs-projects obs-connect-current obs-log-current
  obs-task-current obs-snapshot-current obs-graph-info obs-sync
)

for c in "${_obs_cmds[@]}"; do
  command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done
if (( ${#missing[@]} == 0 )); then
  _t_pass "all ${#_obs_cmds[@]} obs-* commands defined"
else
  _t_fail "obs-* commands defined" "missing: ${missing[*]}"
fi

_gf_cmds=(
  gfinstall gfinitignore gfcode gffull gfupdate
  gfopen gfreport gfjson gfq gfpath gfexplain gfai
  gfaz gfazcopy gfazstatus gfship gfobsidian
  gfhook gfagents gfstatus gfhelp
)

missing=()
for c in "${_gf_cmds[@]}"; do
  command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done
if (( ${#missing[@]} == 0 )); then
  _t_pass "all ${#_gf_cmds[@]} gf* commands defined"
else
  _t_fail "gf* commands defined" "missing: ${missing[*]}"
fi

_az_aliases=(az azhome aztoday azcap aztask azfind azsync azconnect azsnap azlog aztodo azprojects azbind azgraph)

missing=()
for a in "${_az_aliases[@]}"; do
  alias "$a" >/dev/null 2>&1 || missing+=("$a")
done
if (( ${#missing[@]} == 0 )); then
  _t_pass "all ${#_az_aliases[@]} az* aliases defined"
else
  _t_fail "az* aliases defined" "missing: ${missing[*]}"
fi

_gf_aliases=(gfs gfi gfc gff gfu gfo gfr gfj gfa gfsh gfoz)

missing=()
for a in "${_gf_aliases[@]}"; do
  alias "$a" >/dev/null 2>&1 || missing+=("$a")
done
if (( ${#missing[@]} == 0 )); then
  _t_pass "all ${#_gf_aliases[@]} gf* aliases defined"
else
  _t_fail "gf* aliases defined" "missing: ${missing[*]}"
fi
