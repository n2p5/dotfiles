#!/bin/sh
# provision/tools.sh — Layer 1b: user-level dev tools via mise. No sudo.
#
# Installs mise (→ ~/.local/bin) if missing, then installs every tool declared
# in the global mise config. Reads the config straight from this checkout
# (home/dot_config/mise/config.toml) so it works before chezmoi has applied it.
# Idempotent: `mise install` skips tools already at the requested version.
set -eu

export PATH="$HOME/.local/bin:$PATH"

command -v mise >/dev/null 2>&1 || curl -fsSL https://mise.run | sh

dir="$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || true)"
cfg="$dir/../home/dot_config/mise/config.toml"
if [ -f "$cfg" ]; then
  MISE_GLOBAL_CONFIG_FILE="$cfg" mise install
else
  # Standalone `curl | sh` run: no checkout beside us; use the applied config.
  mise install
fi

echo "provision/tools.sh: done"
