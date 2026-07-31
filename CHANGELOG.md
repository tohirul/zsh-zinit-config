# Changelog

All notable changes to this framework are documented here.

## [Unreleased]

### Portability & determinism (working tree, branch `test`)

This work turns the framework into a **portable, deterministic baseline** that
can be reproduced and verified from a clean checkout — no machine-specific
absolute paths in committed runtime code, no network at startup, and a
hermetic regression suite.

### Added
- **Graphify tool split** — `tools/graphify.zsh` is now a thin loader over
  seven parts under `tools/graphify/` (`core`, `staging`, `build`, `query`,
  `azkaban`, `installers`, `help`). Public command names are unchanged.
- **Obsidian tool split** — `tools/obsidian.zsh` loader over
  `tools/obsidian/` (`core`, `markdown`, `notes`, `projects`, `sync`,
  `aliases`). Public command names are unchanged.
- **Standalone installers** under `scripts/`:
  - `scripts/bootstrap.zsh` — idempotent one-time setup (Zinit install,
    `local.zsh` from example, `~/.zshrc` mirror with timestamped backup,
    `zcompile` precompilation). Safe to run repeatedly.
  - `scripts/install-zinit.zsh` — installs Zinit under `$ZINIT_HOME`
    (default `~/.local/share/zinit/zinit.git`); early-exits 0 if present.
  - `scripts/install-graphify.sh` — POSIX installer for the `graphify` CLI
    (uv-based). Deliberately has no `set -e`/`exit` so it can be sourced
    in-session by `gfinstall`; it is also runnable directly.
- **Hermetic regression suite** under `tests/`:
  - `tests/run.zsh` — runner; sources only the loaders under test, never
    `zsh_backuprc.zsh` (which would touch Zinit / live shell state).
  - `tests/test_helper.zsh` — pure-zsh assertion helpers (`_t_*`).
  - `tests/cases/commands.zsh` — public API parity for `obs-*`/`gf*`/`az*`.
  - `tests/cases/obsidian.zsh` — markdown helpers, project connect/bind/
    snapshot, capture/task, sync dry-run (temp vault + git repos).
  - `tests/cases/graphify.zsh` — `_gf_slug`, `_gf_md_section` idempotency,
    `gfhelp` coverage, `gfaz` hub-index idempotency, `gfinstall` failure
    path, `gfinitignore`, loader re-source idempotency, no `graphify-out/`
    leak.
- **CI upgrade** (`.github/workflows/lint.yml`): syntax check now covers
  `tools/*/*.zsh`, `scripts/*.zsh`, `tests/*.zsh`, `tests/cases/*.zsh` plus
  `sh -n` for `scripts/*.sh`; source-once guard check covers nested parts;
  smoke-source covers nested parts; a **regression test step** runs
  `zsh tests/run.zsh`.
- **Docs**: `structure.md` tree refresh, `docs/TESTING.md`,
  `docs/OBSIDIAN.md`, `docs/GRAPHIFY.md`, `LICENSE` (MIT), `CHANGELOG.md`.

### Changed
- `gfcode` now honors the `$GRAPHIFY_CODE_STAGE` env var (declared once in
  `tools/graphify/core.zsh`) instead of embedding a duplicated default
  literal. Default value is unchanged:
  `${XDG_CACHE_HOME:-$HOME/.cache}/graphify-staging`.
- `gfinstall` delegates to `scripts/install-graphify.sh` (the network
  bootstrap lives in a reviewed, versioned script instead of inline in the
  sourced toolset). Command name, arguments, and PATH persistence are
  unchanged.
- `.gitignore` now ignores `.audit/`, `local.zsh`, `*.zwc`, and
  `graphify-out/`-adjacent runtime artifacts.

### Removed
- Dead Obsidian helpers that predated the split (never referenced anywhere in
  the repo): `_obs_maybe_open_file`, `_obs_note_rel_from_abs`,
  `_obs_existing_note`, `_obs_time`.

### Breaking changes
- None to public command names. Behavioral notes:
  - `gfcode` output location is now configurable via `$GRAPHIFY_CODE_STAGE`
    (default unchanged).
  - `gfinstall` requires `$ZSH_HOME/scripts/install-graphify.sh` to exist;
    it exits 1 with a message otherwise (a fresh clone has it).
