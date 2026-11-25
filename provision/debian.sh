#!/bin/sh
# provision/debian.sh — Layer 1: system tooling for a Debian/Ubuntu box.
#
# Companion to provision/Brewfile (macOS). TOOLS ONLY — config is applied
# separately by wire.sh (chezmoi). Needs sudo (or root).
#
# Idempotent by presence-detection: every step skips if the tool is already
# installed, so re-runs are cheap and it no-ops whatever agentworks (or a prior
# run) already put in place — e.g. the apt tools agentworks installs via
# vm_template.apt. Deliberately does NOT `apt-get upgrade`: installing the tools
# we need must never turn into an unplanned full-system upgrade.
set -eu

export DEBIAN_FRONTEND=noninteractive
# Never prompt on changed conffiles (keep the existing file; use the package
# default only where there's no local change). Without this, apt blocks forever
# on a dpkg conffile prompt in a non-interactive context (e.g. an agentworks
# SSH run) and the caller times out.
APT_OPTS='-o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef'

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

mkdir -p "$HOME/.local/bin"
# Put ~/.local/bin on PATH so the presence guards below see tools a prior run
# installed (claude); otherwise the vendor installs re-run every time.
export PATH="$HOME/.local/bin:$PATH"

# --- apt --------------------------------------------------------------------
# APT_PACKAGES is the shared set that agentworks ALSO pre-installs via its
# vm_template.apt (in a roomier 300s window, before this script). Keep the two
# in sync — provision/check-apt-drift.py guards that. It's one flat line on
# purpose: trivial for the drift tool to parse.
APT_PACKAGES="zsh tmux tmuxinator ripgrep fzf entr cloc shellcheck luarocks htop procps wget pwgen nmap git curl gh jq ca-certificates xz-utils"
# Heavy extras for bare-metal / exe.dev only. qemu is big + slow (~2min to
# install) and unneeded on agentworks VMs, which set SKIP_HEAVY=1 so it can't
# blow their 120s dotfiles window. NOT in vm_template.apt, so the drift tool
# ignores it. qemu-system-x86 (not the qemu-system metapackage, which pulls
# emulators for every arch).
APT_PACKAGES_HEAVY="qemu-system-x86 qemu-utils"
# go, neovim, etc: absent on purpose — apt's builds are stale; mise owns them
# (provision/tools.sh).

# Recover any half-configured state left by a previously interrupted apt run,
# then install. apt-get install is naturally idempotent (installed packages are
# skipped), so whatever vm_template.apt pre-installed no-ops here.
$SUDO dpkg --configure -a || true
$SUDO apt-get update
heavy=""
[ "${SKIP_HEAVY:-0}" = "1" ] || heavy="$APT_PACKAGES_HEAVY"
# shellcheck disable=SC2086  # APT_OPTS + package lists must word-split
$SUDO apt-get install -y $APT_OPTS $APT_PACKAGES $heavy

# --- vendor channels: tools apt has stale or missing ------------------------
# Each guarded by presence-detection: skip if already on PATH.

# claude code (native installer; self-updates thereafter)
command -v claude >/dev/null 2>&1 || \
  curl -fsSL https://claude.ai/install.sh | bash

# chezmoi, neovim, jj, zig, rust, go, herdr, ... are NOT installed here: they
# are declared in home/dot_config/mise/config.toml and installed per-user by
# provision/tools.sh (mise). This layer is only what needs sudo.

# tailscale — install only. NEVER `tailscale up` here: a clone would duplicate
# the node identity (this bit us — a clone hijacked a live VM's tailnet node).
# Authenticate per-machine, by hand.
command -v tailscale >/dev/null 2>&1 || \
  curl -fsSL https://tailscale.com/install.sh | sh

# oh-my-zsh — KEEP_ZSHRC protects a chezmoi-applied ~/.zshrc on re-runs
[ -d "$HOME/.oh-my-zsh" ] || KEEP_ZSHRC=yes sh -c \
  "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# --- login shell: set to zsh only if it isn't already ------------------------
zsh_path=$(command -v zsh)
if [ "$(getent passwd "$(id -un)" | cut -d: -f7)" != "$zsh_path" ]; then
  $SUDO chsh -s "$zsh_path" "$(id -un)"
fi

echo "provision/debian.sh: done"
