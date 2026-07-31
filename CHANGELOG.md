# Changelog

All notable changes to this framework are documented here.

## [Unreleased]

### Security & data-safety hardening (working tree, branch `test`)

Follow-up pass on top of the module split below: closes the data-loss,
false-success, and staging-security gaps the split introduced. Every item
has a regression test (`zsh tests/run.zsh`: 85 → 186 assertions).

#### Added
- **Early/late config split**: `local.env.zsh` (variables only, sourced
  right after `ZSH_HOME` is resolved, before Zinit/tools) alongside the
  existing late `local.zsh` (aliases/functions, sourced last). See
  `local.env.zsh.example`.
- **Pinned Zinit plugin lifecycle**: `plugins.lock` + manual
  `scripts/install-plugins.zsh`. `zsh_backuprc.zsh` now only declares a
  plugin group to Zinit if its clone directory already exists; a missing
  plugin prints one warning instead of being cloned from an interactive
  shell.
- **Graphify build transactions** (`_gf_make_stage`, `_gf_validate_output`,
  `_gf_install_output` in `tools/graphify/core.zsh`): `gffull`/`gfcode`
  build into a backed-up/staged location and only replace `graphify-out/`
  after the new output validates; a failed or interrupted build restores
  the previous output instead of leaving the project without a graph.
- **Graphify staging security**: `gfcode`'s Python copy step now rejects
  symlinks, out-of-root paths, non-regular files, and oversized files
  (`GRAPHIFY_MAX_FILE_SIZE`, default 2 MiB); stages into a fresh
  `mktemp -d` (mode 700) with a signal-safe cleanup trap
  (`GRAPHIFY_KEEP_STAGE=1` to retain); writes a
  `graphify-stage-manifest.json`.
- **Obsidian managed-block safety**: `_obs_append_or_replace_block`
  validates BEGIN/END marker counts before touching a file (a missing or
  duplicated marker is refused, original left untouched) and writes via a
  same-directory temp file + atomic rename.
- **`obs-sync` truthfulness**: every `git` step's exit code is checked;
  "Vault synced." only prints after a successful pull+push.
- **`AZKABAN_AUTO_OPEN` is now actually enforced** across
  `obs-home`/`obs-open`/`obs-today`/`obs-note` (previously decorative).
- **Snapshot filenames** include a nanosecond timestamp — two snapshots
  created in the same second no longer collide.
- New test cases: `tests/cases/{startup,audit,node,python,
  graphify_hardening,obsidian_hardening,support_tools}.zsh`, plus
  `tests/fixtures/{fake-bin,fake-nvm}/`.
- CI: `permissions: contents: read`, `concurrency`, `timeout-minutes: 15`,
  a dangerous-startup-pattern grep, a machine-path grep, and a
  `zsh_audit` step (against a mirrored `~/.zshrc`).

#### Fixed
- `tools/audit.zsh` checks [12] (duplicate functions) and [13]
  (hardcoded paths) computed a local counter that was never folded into
  the aggregate `rc_failures` — a real duplicate/hardcoded-path could
  print a red `FAIL` and the audit would still report "passed". Fixed,
  and extended with duplicate-alias, alias/function-collision, and
  duplicate-guard-identifier checks (now 21 checks total).
- `gfai` wrapped `graphify query`'s exit status in `|| true` and wrote
  straight to the final `AI_CONTEXT.md` — a failed query silently
  "succeeded" and could overwrite a previous good context file. Now
  writes to a temp file, checks the real exit code, and only installs
  (and clipboard-copies) on success.
- `gfaz`/`gfazcopy`/`gfazstatus`/`gfship`/`gfobsidian` didn't validate the
  project name before using it in a note filename — a name containing `/`
  or `..` is now rejected.
- CI's smoke-source step had no `set -e` inside the `zsh -c` block and
  ended on an unconditional `echo`, so a failing `source` didn't fail the
  step. Each `source` is now explicitly exit-code-checked.
- Node lazy wrappers (`node`/`npm`/`pnpm`/`bun`) used to `unset -f`
  themselves *before* confirming `nvm` loaded — a failed load left them
  permanently gone for the session. They no longer self-delete; a `yarn`
  wrapper was added (previously missing); `ni`/`nr` now route through the
  same dispatcher instead of bypassing it.
- Conda readiness (`_conda_loaded`) checked `command -v conda`, which
  matches a bare executable with no shell hook loaded; switched to
  checking for the `conda` shell function. `_conda_root` now honors
  `$CONDA_ROOT`. `py_install`/`py_pip_install` refuse an unset or `base`
  env unless `PY_ALLOW_BASE=1`. `.conda-env` content is validated
  (single line, no shell metacharacters) before being handed to
  `conda activate`.
- `code_settings_set` printed "Updated setting" even when the write
  failed, and used a `$TMPDIR` temp file (not same-directory, so the
  final `mv` wasn't guaranteed atomic). Fixed on both counts.
- `dreset-project`'s `DRESET_VOLUMES` check used `[[ -n ... ]]`, so
  `DRESET_VOLUMES=0` enabled volume removal instead of disabling it.
  Fixed to compare by value; added `--dry-run` and step-by-step
  exit-code checks.
- `gclean-merged` parsed `git branch`'s human-readable output; switched
  to `git for-each-ref --format=...`. A failed `git fetch -p` is now
  surfaced as a warning instead of silently swallowed.
- `prime-select query` (read-only) no longer runs under `sudo`; `nvtop`/
  `glxinfo` are existence-guarded; `prun-gl`/`prun-vk` only add
  Chromium-specific CLI flags when the target binary is actually a
  Chromium/Electron-family command.
- `oc_node`/`oc_python`/`oc_docker` used `find | xargs`, which
  word-splits paths containing spaces; switched to the same
  fzf-selection-into-a-variable pattern already used by `oc_projects`.
  `oc_docker` now recognizes all four Compose filenames.
- `dev_clean --force` had no project-root check — it refuses to run in
  `$HOME`, `/`, `/tmp`, or a directory with no recognizable project
  markers.

#### Changed
- `AZKABAN_DIR` (Graphify) now defaults from `AZKABAN_VAULT` (Obsidian)
  instead of an independent `$HOME/azkaban` literal — set
  `AZKABAN_VAULT` once and both subsystems follow it. `zsh_audit` warns
  (non-blocking) if they're ever set to different explicit values.
- `gfinitignore` checks and appends each required ignore entry
  independently (idempotent) instead of overwriting the whole file with
  a timestamped backup each run.
- Obsidian's `_obs_yaml_escape` and the new `_obs_md_table_escape` are
  applied to table cells in `obs-project-bind`'s output.

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
