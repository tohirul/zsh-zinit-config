# Graphify workflow

`tools/graphify.zsh` is a thin loader over `tools/graphify/`:

| part         | contents                                            |
| ------------ | --------------------------------------------------- |
| `core.zsh`   | env config + internal helpers (`_gf_*`)             |
| `staging.zsh`| `gfcode` (code-only staging graph build)            |
| `build.zsh`  | `gffull <backend>`, `gfupdate`                      |
| `query.zsh`  | `gfopen/gfreport/gfjson/gfq/gfpath/gfexplain/gfai`  |
| `azkaban.zsh`| `gfaz`, `gfazcopy`, `gfazstatus`, `gfship`, `gfobsidian` |
| `installers.zsh` | `gfinstall`, `gfinitignore`, `gfhook`, `gfagents` |
| `help.zsh`   | `gfstatus`, `gfhelp`, `gf*` short aliases           |

## Model

Runtime graph artifacts stay **inside each project repo** under
`<repo>/graphify-out/`. Azkaban (`$AZKABAN_DIR`) only ever receives
lightweight **Markdown bridge notes**:

`AZKABAN_DIR` defaults to `${AZKABAN_VAULT:-$HOME/azkaban}` — it's the
same vault Obsidian uses (`$AZKABAN_VAULT`) unless you deliberately point
Graphify at a different one. Set `AZKABAN_VAULT` in `local.env.zsh` and
both subsystems follow it; `zsh_audit` warns (non-blocking) if the two
variables ever hold different explicit values.

```
Cortext.md
  <-> 04_AI_Workspace/Graphify/README.md            (generic hub)
    <-> 04_AI_Workspace/Graphify/<slug>/metadata.md (per project)
      <-> 05_Projects/Active/Project Graph - <name>.md
        <-> 05_Projects/Active/Project - <name>.md  (human note, never auto-created)
```

Artifact copies into Azkaban happen **only** via explicit `gfazcopy`.

## Typical flow

```bash
cd <repo>
gfinitignore      # create .graphifyignore + .gitignore entries
gfcode            # build <repo>/graphify-out (code-only, offline)
gfaz "Project Name"   # create/update Azkaban bridge notes (never artifacts)
gfopen            # open graph.html
gfq "summarize the architecture"
gfazcopy "Project Name"   # optional: copy artifacts into Azkaban
```

`gfship "Name"` = `gfcode` + `gfaz` + `gfopen`. `gfobsidian "Name"` is the
full (non-default) Obsidian export; it needs a backend if the repo has
docs/images/PDFs.

## Contract notes

- `gfaz "Name"` **fails** unless `<repo>/graphify-out/graph.json` exists.
- `gfaz` **never creates** the human project note — it prints an explicit
  path hint instead. Pass an explicit path with
  `gfaz "Name" "/path/to/project-note.md"`.
- `gfaz`/`gfazcopy`/`gfazstatus`/`gfship`/`gfobsidian` reject a project
  name containing `/` or `..` — it ends up directly in a note filename
  (`Project Graph - <name>.md`), so a crafted name can't escape
  `05_Projects/Active/`. `$name`/`$root` are YAML-escaped in frontmatter.
- The hub's `## Project graph index` section is managed with an
  ensure-line strategy: each project is indexed exactly once, even across
  repeated `gfaz` runs.

## Build safety (gfcode / gffull / gfupdate)

- **Transactional installs.** Neither `gfcode` nor `gffull` ever deletes
  the project's `graphify-out/` before a new build is known-good. `gffull`
  renames the existing output aside, builds, and only drops the backup
  once the new output passes validation (non-empty `graph.json` that
  parses as JSON, non-empty `GRAPH_REPORT.md`) — on any failure the
  previous output is restored. `gfcode` builds entirely in a separate
  staging directory and only swaps `graphify-out/` in at the very end,
  via the same validate-then-install step.
- **Staging is sandboxed.** `gfcode` stages into a fresh, unpredictable
  `mktemp -d` directory under `$GRAPHIFY_CODE_STAGE`
  (`${XDG_CACHE_HOME:-$HOME/.cache}/graphify-staging`, mode `700`) — not a
  deterministic per-project path. It's removed automatically on success,
  failure, or interruption (`EXIT`/`INT`/`TERM`/`HUP`); set
  `GRAPHIFY_KEEP_STAGE=1` to keep it for debugging.
- **Staging rejects:** symlinks (file or directory), any resolved path
  outside the project root, non-regular files (sockets/FIFOs/devices),
  and files over `$GRAPHIFY_MAX_FILE_SIZE` (default 2 MiB). Secret-looking
  filenames (`.env*`, `*secret*`, `*token*`, `*credentials*`, `*.pem`,
  `*.key`, `*.p12`, `*.pfx`, `id_rsa*`, `id_ed25519*`) are excluded before
  the extension allowlist is even checked. A `graphify-stage-manifest.json`
  is written into the stage recording what was copied/excluded and why.

## Query commands

`gfq`/`gfpath`/`gfexplain`/`gfai` always run `graphify` with the working
directory set to the resolved project root (not wherever the shell
happened to be). `gfai` writes its answer to a temp file first and only
installs it as `AI_CONTEXT.md` (and only copies to the clipboard) if the
underlying `graphify query` actually succeeded — a failed query returns
non-zero and leaves any previous `AI_CONTEXT.md` untouched, instead of
silently overwriting it with error text.

## Install

`gfinstall` delegates to `scripts/install-graphify.sh` (POSIX sh, uv-based,
source-safe). The script verifies `graphify` is actually reachable after
installing and only reports success in that case; `gfinstall` propagates
its real exit status. `gfhook install|status|uninstall` and `gfagents`
manage Graphify's git hooks / agent instructions.
