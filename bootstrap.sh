#!/bin/sh
# bootstrap.sh — one-shot setup for a Debian/Ubuntu box (e.g. an exe.dev devbox).
#
#   curl -fsLS https://raw.githubusercontent.com/n2p5/dotfiles/main/bootstrap.sh | sh
#
# Orchestrates two peers, in order:
#   1. provision/debian.sh — tools (apt + vendor installers + oh-my-zsh)
#   2. chezmoi             — config (init --apply on first run; update after)
#
# Suitable as an exe.dev account-wide setup script via indirection:
#   printf '#!/bin/bash\ncurl -fsLS https://raw.githubusercontent.com/n2p5/dotfiles/main/bootstrap.sh | sh\n' \
#     | ssh exe.dev defaults write dev.exe new.setup-script
set -eu

command -v apt-get >/dev/null 2>&1 || {
  echo "bootstrap.sh: Debian/Ubuntu only (no apt-get found)" >&2
  exit 1
}

RAW="https://raw.githubusercontent.com/n2p5/dotfiles/main"
# download then run, so a failed fetch aborts here (set -e) instead of being
# swallowed by the pipe — /bin/sh has no pipefail, so `curl ... | sh` would
# report success on a 404 and leave a half-provisioned box.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsLS "$RAW/provision/debian.sh" -o "$tmp"
sh "$tmp"

export PATH="$HOME/.local/bin:$PATH"
if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
  chezmoi update
else
  chezmoi init --apply n2p5/dotfiles
fi

echo "bootstrap.sh: complete — start a new shell to land in zsh"
