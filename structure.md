```
└── 📁.zsh
    ├── aliases.zsh              # simple, non-conflicting aliases (incl. az*/gf*)
    ├── functions.zsh            # user workflows
    ├── zsh_backuprc.zsh         # clean snapshot of ~/.zshrc (thin orchestrator)
    ├── local.zsh.example        # machine-local override template (local.zsh is git-ignored)
    ├── readme.md
    ├── structure.md
    ├── CHANGELOG.md
    ├── LICENSE
    ├── 📁lib
    │   ├── errors.zsh           # shared error helpers
    │   └── utils.zsh            # shared utilities
    ├── 📁tools
    │   ├── ai.zsh               # AI coding adapters (claude/gemini/…)
    │   ├── audit.zsh            # framework self-audit (zsh_audit)
    │   ├── dev-agent.zsh        # agent skills helpers
    │   ├── docker.zsh
    │   ├── git.zsh
    │   ├── gpu.zsh              # NVIDIA PRIME launchers (prun, codegpu, …)
    │   ├── node.zsh             # nvm-based, lazy
    │   ├── opencode.zsh         # OpenCode workflow adapters (oc_*)
    │   ├── python.zsh           # conda-only, lazy
    │   ├── system.zsh           # Ubuntu diagnostics
    │   ├── vscode.zsh
    │   ├── obsidian.zsh         # LOADER → tools/obsidian/
    │   └── graphify.zsh         # LOADER → tools/graphify/
    │   ├── 📁obsidian           # Obsidian/Azkaban automation parts
    │   │   ├── core.zsh         # layout vars, guards, message/slug/date/git helpers
    │   │   ├── markdown.zsh     # yaml escaping, wikilinks, block replacement
    │   │   ├── notes.zsh        # obs-home/open/today/capture/task/note/find
    │   │   ├── projects.zsh     # connect/bind/log/task/snapshot, graph info
    │   │   ├── sync.zsh         # obs-sync (git vault sync)
    │   │   └── aliases.zsh      # az* shortcuts
    │   └── 📁graphify           # Graphify project-graph workflow parts
    │       ├── core.zsh         # env config + internal helpers (_gf_*)
    │       ├── staging.zsh      # gfcode (code-only staging graph build)
    │       ├── build.zsh        # gffull, gfupdate
    │       ├── query.zsh        # gfopen/report/json/q/path/explain/ai
    │       ├── azkaban.zsh      # gfaz, gfazcopy, gfazstatus, gfship, gfobsidian
    │       ├── installers.zsh   # gfinstall, gfinitignore, gfhook, gfagents
    │       └── help.zsh         # gfstatus, gfhelp, gf* short aliases
    ├── 📁scripts
    │   ├── bootstrap.zsh        # idempotent one-time setup (zinit, local.zsh, rc, zcompile)
    │   ├── install-zinit.zsh    # installs Zinit under $ZINIT_HOME
    │   └── install-graphify.sh  # POSIX installer for the graphify CLI (used by gfinstall)
    ├── 📁tests
    │   ├── run.zsh              # hermetic test runner (zsh tests/run.zsh)
    │   ├── test_helper.zsh      # assertion helpers (_t_*)
    │   └── 📁cases
    │       ├── commands.zsh     # public command/alias parity
    │       ├── obsidian.zsh     # obsidian split regression
    │       └── graphify.zsh     # graphify split regression
    ├── 📁docs
    │   ├── TESTING.md           # how the regression suite works
    │   ├── OBSIDIAN.md          # Obsidian/Azkaban workflow
    │   └── GRAPHIFY.md          # Graphify workflow
    └── 📁.github/workflows
        └── lint.yml             # CI: syntax, guards, smoke-source, regression tests
```

Every module carries a source-once guard (`[[ -n ${_ZSH_…:-} ]] && return` + `typeset -g _ZSH_…=1`), so repeated sourcing is always a no-op.
