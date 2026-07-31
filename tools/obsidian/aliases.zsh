# ============================================================
# Obsidian / Azkaban — aliases
# ============================================================
[[ -n ${_ZSH_TOOL_OBSIDIAN_ALIASES:-} ]] && return
typeset -g _ZSH_TOOL_OBSIDIAN_ALIASES=1

alias az='obs-open'
alias azhome='obs-home'
alias aztoday='obs-today'
alias azcap='obs-capture'
alias aztask='obs-task'
alias azfind='obs-find'
alias azsync='obs-sync'

alias azconnect='obs-connect-current'
alias azsnap='obs-snapshot-current'
alias azlog='obs-log-current'
alias aztodo='obs-task-current'
alias azprojects='obs-projects'

alias azbind='obs-project-bind'
alias azgraph='obs-graph-info'
