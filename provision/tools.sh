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
# Standalone `curl | sh` run has no checkout beside us: use the applied config.
[ -f "$cfg" ] && export MISE_GLOBAL_CONFIG_FILE="$cfg"
mise install

# --- neovim plugins ----------------------------------------------------------
# vim.pack installs plugins on first start, but treesitter parsers and
# blink.cmp's prebuilt fuzzy matcher download asynchronously and would be cut
# off by a quick exit. One headless pass that waits for both, so the first
# interactive launch is complete. Skipped until chezmoi has applied the config.
if [ -f "$HOME/.config/nvim/init.lua" ]; then
  echo "provision/tools.sh: neovim plugins + treesitter parsers"
  mise exec -- nvim --headless \
    -c 'lua require("nvim-treesitter").install(vim.g.ts_ensure_installed or {}):wait(600000)' \
    -c 'lua vim.wait(120000, function() return vim.uv.fs_stat(vim.fn.stdpath("data") .. "/site/pack/core/opt/blink.cmp/target/release/libblink_cmp_fuzzy.so") ~= nil end, 500)' \
    -c 'qa' 2>&1
  echo
fi

echo "provision/tools.sh: done"
