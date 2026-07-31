# Obsidian / Azkaban workflow

`tools/obsidian.zsh` is a thin loader over `tools/obsidian/`:

| part        | contents                                              |
| ----------- | ----------------------------------------------------- |
| `core.zsh`  | layout env vars, message/slug/date/url/git helpers    |
| `markdown.zsh` | YAML escaping, wikilinks, managed-block replacement |
| `notes.zsh` | `obs-home/open/today/capture/task/note/find`          |
| `projects.zsh` | connect/bind/log/task/snapshot, graph info          |
| `sync.zsh`  | `obs-sync` (git vault sync)                           |
| `aliases.zsh` | `az*` shortcuts                                     |

## Vault layout (defaults, overridable in `local.zsh`)

```
~/azkaban
├── 00_Inbox/Inbox.md              # obs-capture / obs-task inbox
├── 01_Daily/Daily Notes/          # obs-today / obs-note
├── 02_Tasks/inbox.md
├── 05_Projects/Active/            # obs-project-connect + snapshots
├── 10_Knowledge_Base/Atomic Notes/
└── Cortext.md                     # central second-brain note
```

Override with `AZKABAN_VAULT`, `AZKABAN_INBOX_DIR`, `AZKABAN_PROJECTS_DIR`,
etc.

## Commands

- **Capture**: `obs-capture "note"`, `obs-task "todo" [project]`,
  `obs-note "title"`, `obs-today`.
- **Projects**: `obs-project-connect <repo> "Name"` (creates the project
  note + `.azkaban/project.md` + index entry), `obs-project-bind`,
  `obs-project-snapshot <repo> "Name"` (writes a `LATEST-SNAPSHOT` block —
  idempotent), `obs-project-log`, `obs-project-task`, `obs-projects`.
- **Graph**: `obs-graph-info` (vault note graph), `obs-connect-current`,
  `obs-log-current`, etc. for the current directory.
- **Sync**: `obs-sync [--dry-run]` commits vault changes (dry-run never
  commits).

Wikilinks are written without the `.md` extension (Obsidian convention), e.g.
`[[05_Projects/Active/my-project|My Project]]`.

Managed blocks use HTML-comment fences:
`<!-- AZKABAN:<BLOCK>:BEGIN --> … <!-- AZKABAN:<BLOCK>:END -->` so one block
per key is always guaranteed.
