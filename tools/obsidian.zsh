# ============================================================
# Obsidian / Azkaban automation helpers (LOADER)
# ============================================================
# Splits the former monolith into parts under tools/obsidian/:
#   core       layout vars, guards, message/slug/git helpers
#   markdown   wikilinks, block replacement, yaml escaping
#   notes      obs-home/open/today/capture/task/note/find
#   projects   connect/bind/log/task/snapshot, graph info
#   sync       obs-sync (git vault sync)
#   aliases    az* shortcuts
# ============================================================
[[ -n ${_ZSH_TOOL_OBSIDIAN:-} ]] && return
typeset -g _ZSH_TOOL_OBSIDIAN=1

source "$ZSH_HOME/tools/obsidian/core.zsh"
source "$ZSH_HOME/tools/obsidian/markdown.zsh"
source "$ZSH_HOME/tools/obsidian/notes.zsh"
source "$ZSH_HOME/tools/obsidian/projects.zsh"
source "$ZSH_HOME/tools/obsidian/sync.zsh"
source "$ZSH_HOME/tools/obsidian/aliases.zsh"
