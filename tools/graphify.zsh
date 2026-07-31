# ============================================================
# Graphify workflow layer (LOADER)
# ============================================================
# Splits the former monolith into parts under tools/graphify/:
#   core        config exports + internal helpers (_gf_*)
#   staging     gfcode (code-only staging graph build)
#   build       gffull, gfupdate (full/update in-repo builds)
#   query       gfopen/report/json/q/path/explain/ai
#   azkaban     gfaz, gfazcopy, gfazstatus, gfship, gfobsidian
#   installers  gfinstall, gfinitignore, gfhook, gfagents
#   help        gfstatus, gfhelp, short aliases
# ============================================================
[[ -n ${_ZSH_TOOL_GRAPHIFY:-} ]] && return
typeset -g _ZSH_TOOL_GRAPHIFY=1

source "$ZSH_HOME/tools/graphify/core.zsh"
source "$ZSH_HOME/tools/graphify/staging.zsh"
source "$ZSH_HOME/tools/graphify/build.zsh"
source "$ZSH_HOME/tools/graphify/query.zsh"
source "$ZSH_HOME/tools/graphify/azkaban.zsh"
source "$ZSH_HOME/tools/graphify/installers.zsh"
source "$ZSH_HOME/tools/graphify/help.zsh"
