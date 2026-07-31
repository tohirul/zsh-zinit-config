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

## Vault layout (defaults, overridable in `local.env.zsh`)

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
  commits). Every `git` step (add, commit, pull --rebase, push) is
  exit-code-checked — `obs-sync` only prints "Vault synced." once the
  pull and push actually succeeded, and returns non-zero (with a specific
  error) on any failure, including a hook rejecting the commit or a
  conflicted rebase.

Wikilinks are written without the `.md` extension (Obsidian convention), e.g.
`[[05_Projects/Active/my-project|My Project]]`. Labels are sanitized (`]]`
stripped, `|` replaced) so an untrusted label can't break wikilink syntax.

## Managed blocks (data-safety)

Managed blocks use HTML-comment fences:
`<!-- AZKABAN:<BLOCK>:BEGIN --> … <!-- AZKABAN:<BLOCK>:END -->`. The
rewriter (`_obs_append_or_replace_block`) only accepts two marker states:
zero of each (appends a fresh block) or exactly one of each in the right
order (replaces it). Anything else — a missing `END`, duplicate markers,
reversed order — is refused outright and the note is left byte-for-byte
unchanged; the write itself is atomic (same-directory temp file + rename),
so an interrupted write can't leave a half-written note either.

## Auto-open

GUI/URI-handler launches (`obs-home`, `obs-open`, `obs-today`, `obs-note`)
are gated behind `AZKABAN_AUTO_OPEN` (default `0`) — nothing opens unless
you set `AZKABAN_AUTO_OPEN=1` in `local.env.zsh`.

## Snapshots

`obs-project-snapshot` filenames include a nanosecond timestamp
(`snapshot-<date>-<time>-<nanoseconds>.md`), so two snapshots created in
immediate succession never collide/overwrite each other.

## Escaping

YAML frontmatter values go through `_obs_yaml_escape` (backslashes,
quotes, and embedded newlines). Markdown table cells (project bind's
`.azkaban/project.md` and the note's `REPO-CONNECTION` block) go through
`_obs_md_table_escape` (pipes, backticks, newlines) so a project name or
branch name containing `|` or `` ` `` can't corrupt the table.
