#!/bin/sh
# bootstrap.sh — full setup for a FRESH Debian/Ubuntu box: Layer 1 (tools) then
# Layer 2 (dotfiles). For exe.dev devboxes, bare metal, or an agentworks admin's
# one-time tooling. It installs system packages and changes your login shell, so
# it is NOT meant to run unattended on an established box.
#
#   AGW_BOOTSTRAP=1 curl -fsLS https://raw.githubusercontent.com/n2p5/dotfiles/main/bootstrap.sh | sh
#
#   Layer 1  provision/debian.sh — system tools (apt + vendor), needs sudo
#   Layer 2  wire.sh             — dotfiles config via chezmoi, no sudo
#
# Toggles:
#   WIRE_ONLY=1      skip Layer 1 (config only; e.g. an agent inheriting VM tools)
#   AGW_BOOTSTRAP=1  confirm a non-interactive Layer-1 run (safety interlock)
set -eu

command -v apt-get >/dev/null 2>&1 || {
  echo "bootstrap.sh: Debian/Ubuntu only (no apt-get found)" >&2
  exit 1
}

# --- safety interlock --------------------------------------------------------
# Layer 1 mutates the system (apt, /usr/local, login shell). Require explicit
# intent so a mis-fired automated run can't clobber an established box (this
# session had a clone hijack a live VM — belt and suspenders).
if [ "${WIRE_ONLY:-0}" != "1" ] && [ "${AGW_BOOTSTRAP:-0}" != "1" ]; then
  if [ -t 0 ]; then
    printf 'bootstrap.sh will install system tools and change the login shell on THIS box (%s).\nProceed? [y/N] ' "$(hostname)"
    read -r ans
    case "$ans" in y | Y | yes) ;; *) echo "aborted." ; exit 1 ;; esac
  else
    echo "bootstrap.sh: refusing unattended Layer-1 run (system provisioning is destructive)." >&2
    echo "  Fresh boxes only: set AGW_BOOTSTRAP=1 to confirm, or WIRE_ONLY=1 for config-only." >&2
    exit 1
  fi
fi

RAW="https://raw.githubusercontent.com/n2p5/dotfiles/main"
dir="$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || true)"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Run a repo script from this checkout if present, else fetch it from GitHub
# (covers both the agentworks clone and a standalone `curl | sh`).
run_layer() {  # $1 = repo-relative script path
  if [ -n "$dir" ] && [ -f "$dir/$1" ]; then
    sh "$dir/$1"
  else
    curl -fsLS "$RAW/$1" -o "$tmp"
    sh "$tmp"
  fi
}

if [ "${WIRE_ONLY:-0}" != "1" ]; then
  echo "bootstrap.sh: Layer 1 — tooling (provision/debian.sh)"
  run_layer provision/debian.sh
fi

echo "bootstrap.sh: Layer 2 — dotfiles (wire.sh)"
run_layer wire.sh

echo "bootstrap.sh: complete — start a new shell to land in zsh"
