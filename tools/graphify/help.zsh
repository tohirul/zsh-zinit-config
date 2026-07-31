# ============================================================
# Graphify workflow layer — status / help / short aliases
# ============================================================
[[ -n ${_ZSH_TOOL_GRAPHIFY_HELP:-} ]] && return
typeset -g _ZSH_TOOL_GRAPHIFY_HELP=1

gfstatus() {
  local root="$(_gf_abs "${1:-$(_gf_root)}")" || return 1

  echo "Graphify workflow status"
  echo "------------------------"
  echo "Project:              $root"
  echo "Azkaban:              $AZKABAN_DIR"
  echo "Azkaban graph folder: $AZKABAN_DIR/$GRAPHIFY_WORKSPACE"
  echo "Default backend:      ${GRAPHIFY_DEFAULT_BACKEND:-none}"
  echo

  if command -v graphify >/dev/null 2>&1; then
    echo -n "Graphify:             "
    graphify --version 2>/dev/null || echo "installed"
  else
    echo "Graphify:             missing"
  fi

  [[ -f "$root/graphify-out/graph.json" ]] && echo "Project graph:        yes" || echo "Project graph:        no"
  [[ -f "$root/graphify-out/GRAPH_REPORT.md" ]] && echo "Project report:       yes" || echo "Project report:       no"
}

gfhelp() {
  cat <<'EOF'
Graphify zsh workflow

Runtime artifacts stay in <repo>/graphify-out.
Azkaban receives Markdown bridge notes only (Cortext <-> Hub <-> metadata <-> notes).

Install:
  gfinstall

Project setup:
  gfinitignore                    # create .graphifyignore + gitignore entries

Build:
  gfcode                          # build project-side graphify-out (code-only, offline)
  gffull <backend>                # full graph with backend: ollama, claude-cli, gemini, openai...
  gfupdate                        # update existing graph

Inspect:
  gfopen                          # open project-side graph.html
  gfreport                        # read project-side GRAPH_REPORT.md
  gfjson                          # inspect project-side graph.json
  gfstatus                        # show workflow status

Query:
  gfq "question"                  # query project-side graph
  gfpath "node A" "node B"
  gfexplain "topic"
  gfai "question for an AI coding agent"

Azkaban bridge:
  gfaz "Project Name"             # create/update Azkaban Markdown bridge notes only
  gfaz "Project Name" "/note.md"  # same, with explicit project note path
  gfazcopy "Project Name"         # optional: copy artifacts into Azkaban artifacts folder
  gfazstatus "Project Name"       # inspect project/Azkaban bridge state
  gfship "Project Name"           # gfcode + gfaz + gfopen (no artifact copy)
  gfobsidian "Project Name"       # full Obsidian export into Azkaban (not default)

Hooks / agents:
  gfhook install|status|uninstall
  gfagents                        # install Graphify agent instructions where supported
EOF
}

# Short aliases
alias gfs='gfstatus'
alias gfi='gfinitignore'
alias gfc='gfcode'
alias gff='gffull'
alias gfu='gfupdate'
alias gfo='gfopen'
alias gfr='gfreport'
alias gfj='gfjson'
alias gfa='gfaz'
alias gfsh='gfship'
alias gfoz='gfobsidian'
