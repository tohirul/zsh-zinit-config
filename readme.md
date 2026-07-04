# Zsh Developer Framework (Ubuntu)

A **production-grade Zsh framework** for software and web developers on **Ubuntu**.

This is **not** an Oh-My-Zsh preset or a random plugin collection. It is a **clean, modular, performance-focused shell framework** built to be:

- Fast
- Predictable
- Safe
- Extensible
- Free of shell-startup side effects

This repository represents a **frozen, stable baseline**.

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
- Node.js (nvm-based, multi-PM)
- Python (Conda-only, manual activation)
- System diagnostics (Ubuntu)
- VS Code CLI helpers
- NVIDIA PRIME GPU launchers (`prun`, `codegpu`, `chromevk`, …)
- Framework self-audit (`zsh_audit` / `dev_doctor`)

---

## 🧱 Architecture

```text
~/.zsh
├── aliases.zsh          # simple, non-conflicting aliases
├── functions.zsh        # user workflows
├── lib/
│   ├── errors.zsh       # shared error helpers
│   └── utils.zsh        # shared utilities
└── tools/
    ├── git.zsh
    ├── docker.zsh
    ├── node.zsh
    ├── python.zsh
    ├── system.zsh
    └── vscode.zsh

~/.zshrc                 # thin entrypoint
```

### Design Rules
- `.zshrc` is an orchestrator, not a script
- No tool runs unless explicitly called
- Plugins are async and non-blocking
- Functions own logic; aliases never shadow functions

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
zsh_audit   # full framework self-diagnostic (syntax, duplication, collisions, startup time)
```

All commands should work immediately.

> `~/.zshrc` is a thin orchestrator that sources the modules in `~/.zsh`.
> Every module carries a source-once guard, so it can never be duplicated by
> repeated appends. Run `zsh_audit` any time to confirm the framework is healthy.

---

## 🔒 Baseline Status

This configuration is **frozen** as a baseline.

- No changes unless explicitly requested
- All future improvements must be additive
- No breaking refactors

Suggested tag:

```
zsh-baseline-ubuntu-v1
```

---

## 🔮 Optional Extensions

Not included in the baseline but supported cleanly:
- direnv integration
- atuin history
- dotfiles bootstrap script
- macOS port (separate baseline)
- framework self-diagnostics

---

## 📜 Philosophy

> A shell should be boring, fast, and predictable.
> Productivity comes from clarity, not magic.

---

## 🧾 License

MIT (or your preferred license)
