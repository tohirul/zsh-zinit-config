# Testing

The framework ships a **hermetic regression suite** — no external test
framework, no network, no writes outside the repo.

## Run

```bash
zsh tests/run.zsh
```

The runner exits `0` only when every assertion passes.

## Layout

```
tests/
├── run.zsh           # orchestrator: sources helpers + loaders + all cases
├── test_helper.zsh   # assertion vocabulary (_t_ok, _t_nok, _t_eq, …)
└── cases/
    ├── commands.zsh  # every public obs-*/gf*/az* name must exist
    ├── obsidian.zsh  # obsidian split regression
    └── graphify.zsh  # graphify split regression
```

## Hermeticity guarantees

- `run.zsh` sets `ZSH_HOME="$REPO_ROOT"` and sources **only** the tool
  loaders under test (`tools/obsidian.zsh`, `tools/graphify.zsh`).
- It never sources `zsh_backuprc.zsh`, so no Zinit / live-shell state is
  touched.
- Every case runs against `mktemp`-created directories (temp vaults, temp
  git repos, temp `AZKABAN_DIR`, temp `ZSH_HOME`), all removed at the end.
- The suite asserts that no `graphify-out/` directory ever leaks into the
  framework repo.

## What the cases cover

- **API parity** — every `obs-*` (19), `gf*` (21), `az*` (14) and `gf*`
  alias (11) must resolve after the loaders are sourced.
- **Markdown helpers** — YAML escaping, wikilink building, managed-block
  replace (exactly one BEGIN/END, old content removed).
- **Project flows** — connect → bind → snapshot (twice) → sync `--dry-run`
  (exits 0, never commits).
- **Graphify internals** — `_gf_slug` edge cases, `_gf_md_section`
  replace/ensure-line idempotency, `gfaz` hub-index idempotency across two
  runs, `gfinstall` failure when the installer is missing, loader re-source
  being a no-op.

## CI

`.github/workflows/lint.yml` runs the suite (`zsh tests/run.zsh`) on every
push / PR, in addition to `zsh -n` syntax checks, the source-once guard
check, and the clean-shell smoke-source.
