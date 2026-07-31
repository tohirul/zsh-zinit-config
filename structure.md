```
└── 📁.zsh
    ├── aliases.zsh              # simple, non-conflicting aliases (incl. az*/gf*)
    ├── functions.zsh            # user workflows
    ├── zsh_backuprc.zsh         # clean snapshot of ~/.zshrc (thin orchestrator)
    ├── local.env.zsh.example    # early (variable-only) override template (local.env.zsh is git-ignored)
    ├── local.zsh.example        # late (alias/function) override template (local.zsh is git-ignored)
    ├── plugins.lock             # pinned Zinit plugin revisions (used by scripts/install-plugins.zsh)
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
    │   ├── bootstrap.zsh        # idempotent one-time setup (zinit, local.env.zsh/local.zsh, rc, zcompile)
    │   ├── install-zinit.zsh    # installs Zinit under $ZINIT_HOME
    │   ├── install-plugins.zsh  # installs pinned plugins from plugins.lock (never run at startup)
    │   └── install-graphify.sh  # POSIX installer for the graphify CLI (used by gfinstall)
    ├── 📁tests
    │   ├── run.zsh              # hermetic test runner (zsh tests/run.zsh)
    │   ├── test_helper.zsh      # assertion helpers (_t_*)
    │   ├── 📁fixtures
    │   │   ├── fake-bin/        # curl/wget/git stubs for the startup network test
    │   │   └── fake-nvm/        # fake nvm.sh for the node lazy-loading tests
    │   └── 📁cases
    │       ├── commands.zsh          # public command/alias parity
    │       ├── obsidian.zsh          # obsidian split regression
    │       ├── obsidian_hardening.zsh # malformed blocks, obs-sync failures, auto-open, snapshots
    │       ├── graphify.zsh          # graphify split regression
    │       ├── graphify_hardening.zsh # build/staging transactions, security policy, query cwd
    │       ├── node.zsh              # node lazy-loading
    │       ├── python.zsh            # conda readiness, base-env guard, .conda-env validation
    │       ├── support_tools.zsh     # dev_clean guard, gclean-merged, GPU/vscode/opencode fixes
    │       ├── audit.zsh             # zsh_audit self-tests (clean + injected-bad fixtures)
    │       └── startup.zsh           # isolated startup: no network, no plugin auto-clone
    ├── 📁docs
    │   ├── TESTING.md           # how the regression suite works
    │   ├── OBSIDIAN.md          # Obsidian/Azkaban workflow
    │   └── GRAPHIFY.md          # Graphify workflow
    └── 📁.github/workflows
        └── lint.yml             # CI: syntax, guards, smoke-source, regression tests
```

Every module carries a source-once guard (`[[ -n ${_ZSH_…:-} ]] && return` + `typeset -g _ZSH_…=1`), so repeated sourcing is always a no-op.
