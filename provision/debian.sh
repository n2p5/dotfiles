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
# Put the user-local bindirs on PATH so the presence guards below actually see
# tools a prior run installed. Without this, ~/.local/bin (chezmoi, claude, jj)
# and ~/.cargo/bin (rustup) aren't on PATH during this non-login script, so every
# `command -v` misses and the slow vendor installs re-run every time.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

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
# go: absent on purpose (exe.dev's exeuntu ships the latest go.dev build; apt's
# golang would shadow it). neovim: absent on purpose (apt's build is too old) —
# installed from the official tarball below.

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

# chezmoi → ~/.local/bin
command -v chezmoi >/dev/null 2>&1 || \
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"

# claude code (native installer; self-updates thereafter)
command -v claude >/dev/null 2>&1 || \
  curl -fsSL https://claude.ai/install.sh | bash

# rust via rustup (~/.cargo/bin is on PATH in dot_zshrc)
command -v rustup >/dev/null 2>&1 || \
  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path

# jj — prebuilt musl binary from the latest GitHub release
if ! command -v jj >/dev/null 2>&1; then
  jj_url=$(curl -fsSL https://api.github.com/repos/jj-vcs/jj/releases/latest \
    | jq -r '.assets[].browser_download_url' \
    | grep "$(uname -m)-unknown-linux-musl\.tar\.gz$")
  tmp=$(mktemp -d)
  curl -fsSL "$jj_url" | tar -xz -C "$tmp"
  install -m 0755 "$(find "$tmp" -name jj -type f)" "$HOME/.local/bin/jj"
  rm -rf "$tmp"
fi

# zig — latest stable tarball from ziglang.org
if ! command -v zig >/dev/null 2>&1; then
  zig_url=$(curl -fsSL https://ziglang.org/download/index.json \
    | jq -r "to_entries | map(select(.key != \"master\")) | .[0].value.\"$(uname -m)-linux\".tarball")
  tmp=$(mktemp -d)
  curl -fsSL "$zig_url" | tar -xJ -C "$tmp"
  $SUDO rm -rf /usr/local/zig
  $SUDO mv "$tmp"/zig-* /usr/local/zig
  $SUDO ln -sfn /usr/local/zig/zig /usr/local/bin/zig
  rm -rf "$tmp"
fi

# neovim — official release tarball (apt's build is too old for a modern config)
if ! command -v nvim >/dev/null 2>&1; then
  case "$(uname -m)" in
    x86_64)  nvim_arch="x86_64" ;;
    aarch64) nvim_arch="arm64" ;;
    *) echo "debian.sh: unsupported arch for neovim: $(uname -m)" >&2; exit 1 ;;
  esac
  tmp=$(mktemp -d)
  curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${nvim_arch}.tar.gz" \
    | tar -xz -C "$tmp"
  $SUDO rm -rf "/opt/nvim-linux-${nvim_arch}"
  $SUDO mv "$tmp/nvim-linux-${nvim_arch}" /opt/
  $SUDO ln -sfn "/opt/nvim-linux-${nvim_arch}/bin/nvim" /usr/local/bin/nvim
  rm -rf "$tmp"
fi

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
