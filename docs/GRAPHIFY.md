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
`<repo>/graphify-out/`. Azkaban (`$AZKABAN_DIR`, default `~/azkaban`) only
ever receives lightweight **Markdown bridge notes**:

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
- The hub's `## Project graph index` section is managed with an
  ensure-line strategy: each project is indexed exactly once, even across
  repeated `gfaz` runs.
- `gfcode` stages into `$GRAPHIFY_CODE_STAGE`
  (`${XDG_CACHE_HOME:-$HOME/.cache}/graphify-staging`) — outside the repo.

## Install

`gfinstall` delegates to the reviewed `scripts/install-graphify.sh` (POSIX
sh, uv-based, source-safe). `gfhook install|status|uninstall` and
`gfagents` manage Graphify's git hooks / agent instructions.
