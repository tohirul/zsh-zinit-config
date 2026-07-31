# Testing

The framework ships a **hermetic regression suite** — no external test
framework, no network by default, no writes outside temp directories.

## Run

```bash
zsh tests/run.zsh
```

The runner exits `0` only when every assertion passes. Run it to see the
current assertion count — treat any number printed in prose (including
this doc) as a snapshot, not a guarantee.

## Layout

```
tests/
├── run.zsh           # orchestrator: sources helpers + loaders + all cases
├── test_helper.zsh   # assertion vocabulary (_t_ok, _t_nok, _t_eq, …)
├── fixtures/
│   ├── fake-bin/      # curl/wget/git stubs — trap network calls during the startup test
│   └── fake-nvm/      # fake nvm.sh — lets the node lazy-loading tests run without real nvm
└── cases/
    ├── commands.zsh           # every public obs-*/gf*/az* name must exist
    ├── obsidian.zsh           # obsidian split regression
    ├── obsidian_hardening.zsh # malformed managed blocks, obs-sync git-failure propagation,
    │                          # AZKABAN_AUTO_OPEN gating, snapshot collision-safety, escaping
    ├── graphify.zsh           # graphify split regression
    ├── graphify_hardening.zsh # transactional build/install, staging security policy
    │                          # (symlinks/path-escape/secrets/size), query cwd, gfai failure
    │                          # propagation, project-name path-escape rejection
    ├── node.zsh               # lazy nvm loading, wrapper survival on failed load,
    │                          # standalone tools bypassing nvm, ni/nr routing
    ├── python.zsh             # conda readiness (function, not command -v), CONDA_ROOT
    │                          # override, base-env install refusal, .conda-env validation
    ├── support_tools.zsh      # dev_clean project-root guard, gclean-merged structured refs,
    │                          # GPU chromium-family flag gating, VS Code atomic writes,
    │                          # OpenCode discovery with spaces in paths
    ├── audit.zsh              # zsh_audit self-tests: a clean fixture produces no false
    │                          # positives, a fixture with injected bad patterns is caught
    └── startup.zsh            # isolated `zsh -f` startup: no curl/wget/git-clone, no
                                # plugin auto-clone when none are installed
```

## Hermeticity guarantees

- `run.zsh` sets `ZSH_HOME="$REPO_ROOT"` and sources the tool loaders under
  test plus `lib/errors.zsh`/`lib/utils.zsh` (several tools depend on
  `_jq_guard` and friends).
- It never sources `zsh_backuprc.zsh` directly for the bulk of the suite —
  `startup.zsh` is the one exception, and it does so inside an isolated
  child `zsh -f` with a fake `HOME`/`ZINIT_HOME` and network traps, so it
  can verify the startup contract without touching the real shell.
- Every case runs against `mktemp`-created directories (temp vaults, temp
  git repos, temp `AZKABAN_DIR`/`AZKABAN_VAULT`, temp `ZSH_HOME`), all
  removed at the end.
- Destructive-path tests (`dev_clean --force`) use a fake `$HOME`, never
  the real one.
- The suite asserts that no `graphify-out/` directory ever leaks into the
  framework repo.

## What the cases cover

- **API parity** — every public `obs-*`, `gf*`, and `az*` name resolves
  after the loaders are sourced.
- **Data safety** — a build/write that fails partway must leave the
  previous good state intact (Graphify output, Obsidian managed blocks),
  and must never report success it didn't earn (`obs-sync`, `gfai`,
  `gffull`, VS Code settings writes).
- **Security policy** — Graphify's staging copy is exercised against a
  fixture containing a path-escaping symlink and a credentials file; the
  real `graphify` binary is used when available, so this proves the actual
  pipeline rejects them, not just the isolated helper functions.
- **Audit correctness** — `zsh_audit`'s duplicate/collision/portability
  checks are tested against both a clean fixture (no false positives) and
  a fixture with five different bad patterns injected (all five must be
  caught and must affect the aggregate exit code).

## CI

`.github/workflows/lint.yml` runs, on every push/PR: `zsh -n` syntax
checks, the source-once guard check, a dangerous-startup-pattern grep, a
machine-specific-path grep, the smoke-source step (now fails immediately
on the first module that errors while sourcing), the regression suite
(`zsh tests/run.zsh`), and `zsh_audit` against a mirrored `~/.zshrc`.
