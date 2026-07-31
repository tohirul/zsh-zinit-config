#!/usr/bin/env sh
# Graphify installer — standalone (POSIX sh).
# Normally run via the gfinstall zsh helper, which sources this file
# in-session so the PATH export persists. Also runnable directly:
#   sh "$ZSH_HOME/scripts/install-graphify.sh"
#
# Deliberately free of `exit`/`return`: it must be safe to both source
# from within a zsh function (a bare `exit` would kill the interactive
# shell) and run standalone (a bare `return` errors outside a function
# or sourced script). Instead, every step is exit-code-checked and the
# LAST command in the file is a truthiness check, whose exit status
# becomes the script's own exit status (and `gfinstall`'s return code,
# since `source` propagates it) in either mode.

_graphify_install_ok=1

if ! command -v uv >/dev/null 2>&1; then
  echo "Installing uv..."
  if curl -LsSf https://astral.sh/uv/install.sh | sh; then
    export PATH="$HOME/.local/bin:$PATH"
  else
    echo "uv installer failed (curl | sh)." >&2
    _graphify_install_ok=0
  fi
fi

if [ "$_graphify_install_ok" = 1 ]; then
  if command -v uv >/dev/null 2>&1; then
    if uv tool install -U "graphifyy[pdf,office,mcp,svg,sql]"; then
      uv tool update-shell || echo "Warning: uv tool update-shell failed (PATH may need a manual export)." >&2
    else
      echo "uv tool install failed." >&2
      _graphify_install_ok=0
    fi
  else
    echo "uv is not available; cannot install graphify." >&2
    _graphify_install_ok=0
  fi
fi

if [ "$_graphify_install_ok" = 1 ] && command -v graphify >/dev/null 2>&1; then
  echo "Graphify installed: $(command -v graphify)"
else
  echo "Graphify install failed or graphify is still not on PATH." >&2
  echo '  Try: export PATH="$HOME/.local/bin:$PATH"' >&2
  _graphify_install_ok=0
fi

[ "$_graphify_install_ok" = 1 ]
