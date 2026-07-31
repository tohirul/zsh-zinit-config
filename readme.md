# Zsh Developer Framework (Ubuntu)

A Zsh framework for software and web developers on **Ubuntu**.

This is **not** an Oh-My-Zsh preset or a random plugin collection. It is a **clean, modular, performance-focused shell framework** built to be:

- Fast
- Predictable
- Safe
- Extensible
- Free of shell-startup side effects

Every claim below (startup contract, test coverage, audit checks) is
verified by `zsh tests/run.zsh` and `zsh_audit` — run them yourself to
check the current state; see [CHANGELOG.md](CHANGELOG.md) for what
changed and when.

---

## ✨ Features

### Core
- ⚡ Fast startup (async plugins, cached completion)
- 🧠 Deterministic behavior (no magic, no hidden hooks)
- 🔒 Safe by default
  - No `exit` during init
  - No auto environment activation
  - No alias/function collisions
- 🎯 Developer-centric tooling
- 🧩 Framework architecture (not a flat config)

### UX
- Powerlevel10k with instant prompt
- `fzf` keybindings (Ctrl-R, Ctrl-T, Alt-C)
- `zoxide` for smart directory navigation
- History substring search (↑ / ↓)
- Syntax highlighting & autosuggestions

### Tooling
- Git helpers
- Docker & Docker Compose helpers
- Node.js (nvm-based, multi-PM: npm/pnpm/yarn/bun, real-executable detection)
- Python (Conda-only, manual activation, base-env install guard)
- System diagnostics (Ubuntu)
- VS Code CLI helpers (atomic settings writes)
- NVIDIA PRIME GPU launchers (`prun`, `codegpu`, `chromevk`, …)
- Obsidian / Azkaban automation (`obs-*` commands, `az*` aliases) —
  transactional managed-block writes, truthy `obs-sync`
- Graphify project-graph workflow (`gf*` commands) — code graphs + Azkaban
  bridge notes, transactional builds with rollback, sandboxed staging
- Pinned Zinit plugin lifecycle (`plugins.lock` + `scripts/install-plugins.zsh`)
  — startup never clones a plugin
- Framework self-audit (`zsh_audit` / `dev_doctor`, 21 checks)
- Hermetic regression suite (`zsh tests/run.zsh`)

---

## 🧱 Architecture

```text
~/.zsh
├── aliases.zsh          # simple, non-conflicting aliases (incl. az*/gf*)
├── functions.zsh        # user workflows
├── zsh_backuprc.zsh     # clean snapshot of ~/.zshrc (thin orchestrator)
├── local.env.zsh.example # early (variable-only) machine-local config template
├── local.zsh.example    # late (alias/function) machine-local config template
├── plugins.lock         # pinned Zinit plugin revisions
├── lib/
│   ├── errors.zsh       # shared error helpers
│   └── utils.zsh        # shared utilities
├── tools/
│   ├── git.zsh
│   ├── docker.zsh
│   ├── node.zsh
│   ├── python.zsh
│   ├── system.zsh
│   ├── vscode.zsh
│   ├── obsidian.zsh     # loader → tools/obsidian/*.zsh
│   └── graphify.zsh     # loader → tools/graphify/*.zsh
├── scripts/             # standalone installers (bootstrap, zinit, graphify)
├── tests/               # hermetic regression suite (zsh tests/run.zsh)
└── docs/                # workflow docs

~/.zshrc                 # thin entrypoint
```

`tools/obsidian/` and `tools/graphify/` are split into small parts
(`core`, `markdown`, `notes`, …), each with its own source-once guard.

### Design Rules
- `.zshrc` is an orchestrator, not a script
- No tool runs unless explicitly called
- Plugins are async and non-blocking, and are only ever *loaded* from
  startup if already installed — a missing plugin prints one warning
  instead of being cloned on the spot (see `scripts/install-plugins.zsh`)
- Functions own logic; aliases never shadow functions
- Early config (`local.env.zsh`, variables only) loads before Zinit/tools
  resolve their defaults; late config (`local.zsh`, aliases/functions)
  loads last

---

## 🔌 Plugin Stack

**Plugin manager:** Zinit

### Loaded plugins
- Powerlevel10k (prompt)
- zsh-autosuggestions
- fast-syntax-highlighting
- zsh-completions
- zsh-history-substring-search
- fzf
- zoxide
- zsh-interactive-cd
- Utility plugins:
  - sudo
  - extract
  - colored-man-pages
  - command-not-found

All plugins:
- load asynchronously
- produce no console output during init
- are compatible with Powerlevel10k instant prompt

---

## 🐧 OS Scope

- **Ubuntu only**
- Assumes:
  - `apt`
  - standard Ubuntu paths
- macOS is intentionally out of scope (use a separate baseline)

---

## 🐍 Python Philosophy

- Conda only
- No `venv`, `pipenv`, or `poetry`
- Manual activation per project
- `.conda-env` file maps project → environment
- Lazy loading (zero startup cost)

Example:

```bash
conda_load
py_create api-env 3.11
py_activate api-env
py_mark_env
```

Later:

```bash
py_use_here
```

---

## 🟢 Node.js Philosophy

- Uses `nvm`
- No auto `nvm use`
- Supports npm, yarn, pnpm, bun
- Detects `packageManager` field & lockfiles
- Monorepo-aware

---

## 🐳 Docker Philosophy

- Docker Compose v2
- Project-aware helpers
- Safe cleanup commands
- No destructive defaults

---

## 🚀 Installation (Fresh Ubuntu)

### 1. System dependencies

```bash
sudo apt update
sudo apt install -y \
  git curl jq fzf \
  bat eza fd-find \
  lsof command-not-found
```

Ubuntu fixes:

```bash
ln -s /usr/bin/batcat ~/.local/bin/bat
ln -s /usr/bin/fdfind ~/.local/bin/fd
```

---

### 2. Framework setup

```bash
mkdir -p ~/.zsh
```

Copy the framework files into `~/.zsh` and place `.zshrc` in your home directory.

---

### 3. Set Zsh as default shell (if needed)

```bash
chsh -s $(which zsh)
```

---

### 4. Reload shell

```bash
exec zsh
```

You should see:
- no warnings
- no plugin download output
- instant prompt

---

## 🧪 Health Check

```bash
gs
dps
node_info
py_health
fzf_cd
dev_health
zsh_audit   # full framework self-diagnostic — 21 checks (syntax, duplication, collisions, startup time, ...)
zsh tests/run.zsh   # hermetic regression suite (run it — the assertion count changes as the suite grows)
```

All commands should work immediately.

> `~/.zshrc` is a thin orchestrator that sources the modules in `~/.zsh`.
> Every module carries a source-once guard, so it can never be duplicated by
> repeated appends. Run `zsh_audit` any time to confirm the framework is healthy.

---

## 🔒 Data-safety & security notes

- Graphify (`gfcode`/`gffull`) builds into a private, unpredictable staging
  location and only replaces `graphify-out/` after the new build validates
  (non-empty, JSON-parseable) — a failed or interrupted build leaves the
  previous graph intact. Staging rejects symlinks, out-of-root paths,
  non-regular files, oversized files, and secret-looking filenames.
- Obsidian managed-block writes (`_obs_append_or_replace_block`, used by
  project binding/snapshots) validate marker counts before touching a note;
  a malformed block (missing/duplicate markers) is refused and the file is
  left byte-for-byte unchanged, rather than silently truncated.
- `obs-sync` checks the exit code of every `git` step and only prints
  "Vault synced." when the pull/push actually succeeded.
- Startup never clones a Zinit plugin — see `scripts/install-plugins.zsh`.

---

## 🔮 Optional Extensions

Not included in the baseline but supported cleanly:
- atuin history
- macOS port (separate baseline)

Included now: dotfiles bootstrap (`scripts/bootstrap.zsh`), framework
self-diagnostics (`zsh_audit`), hermetic tests, Obsidian/Azkaban and
Graphify workflows.

---

## 📜 Philosophy

> A shell should be boring, fast, and predictable.
> Productivity comes from clarity, not magic.

---

## 🧾 License

MIT — see [LICENSE](LICENSE).
