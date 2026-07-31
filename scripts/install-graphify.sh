#!/usr/bin/env sh
# Graphify installer — standalone (POSIX sh).
# Normally run via the gfinstall zsh helper, which sources this file
# in-session so the PATH export persists. Also runnable directly:
#   sh "$ZSH_HOME/scripts/install-graphify.sh"
#
# Deliberately free of `set -e` and `exit`: it must be safe to source
# from within a zsh function in an interactive shell.

if ! command -v uv >/dev/null 2>&1; then
  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

uv tool install -U "graphifyy[pdf,office,mcp,svg,sql]"
uv tool update-shell
echo "Graphify installed. Restart terminal or run:"
echo '  export PATH="$HOME/.local/bin:$PATH"'
graphify --version 2>/dev/null || true
