#!/bin/sh
# wire.sh — Layer 2: apply dotfiles config via chezmoi.
#
# NO sudo, NO installs (beyond chezmoi itself, which is user-local). Idempotent.
# Runs for ANY user — the admin, or an isolated agent that inherits the VM's
# Layer-1 tools. This is the fast, safe half of the setup and is exactly what
# agentworks's per-user dotfiles step wants (fits its short SSH window).
#
# Assumes Layer 1 (provision/debian.sh) has already provided the tools the
# configs expect (tmux, nvim, ...). It never installs them — a missing tool just
# means that config is inert until Layer 1 runs.
set -eu

export PATH="$HOME/.local/bin:$PATH"

# chezmoi is user-local (~/.local/bin); install only if missing. No sudo.
command -v chezmoi >/dev/null 2>&1 || \
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"

# Prefer the checkout we're run from — agentworks clones the repo and runs this
# inside it, so apply straight from that source (honors .chezmoiroot). This is
# stateless and idempotent: no `chezmoi init`, no persisted source path to drift,
# so a re-clone-and-re-wire (agentworks reinit) always applies the fresh checkout.
# Fall back to cloning the GitHub repo for a standalone `curl | sh` run with no
# checkout beside us.
src="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
if [ -f "$src/.chezmoiroot" ]; then
  # --force: apply non-interactively even when the target changed since chezmoi
  # last wrote it. agentworks appends its own hook to ~/.zshrc AFTER the dotfiles
  # step, so on the next reinit chezmoi sees the file changed and would prompt
  # ("overwrite?") — fatal in a no-TTY SSH run. Forcing re-establishes the
  # declarative base each time; agentworks re-appends its hook right after.
  chezmoi apply --source "$src" --force
else
  chezmoi init --apply n2p5/dotfiles
fi

echo "wire.sh: dotfiles applied"
