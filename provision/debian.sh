#!/bin/sh
# provision/debian.sh — tool provisioning for a Debian/Ubuntu box.
#
# Companion to provision/Brewfile (macOS). Tools only — config is applied
# separately by chezmoi (see bootstrap.sh). Safe to re-run: apt is naturally
# idempotent; each vendor installer below is wrapped so a re-run either
# no-ops or refreshes the tool to latest.
set -eu

export DEBIAN_FRONTEND=noninteractive

# exe.dev's exedev user has passwordless sudo; plain root needs none.
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

mkdir -p "$HOME/.local/bin"

# --- apt: declarative package list -----------------------------------------
$SUDO apt-get update
$SUDO apt-get upgrade -y
$SUDO apt-get install -y \
  zsh tmux tmuxinator \
  ripgrep fzf entr cloc shellcheck luarocks \
  htop procps wget pwgen nmap \
  qemu-system-x86 qemu-utils \
  git curl gh jq ca-certificates xz-utils
# go is intentionally absent: exe.dev's exeuntu ships the latest go.dev
# build, and apt's golang would shadow it.
# neovim is intentionally absent: noble's 0.9.5 is too old for a modern
# Lua config — installed from the official tarball below instead.
# qemu-system-x86 (not the qemu-system metapackage, which pulls emulators
# for every architecture — hundreds of MB of sparc/mips/alpha).

# --- vendor channels: tools apt has stale or missing ------------------------

# chezmoi → ~/.local/bin (re-run = update to latest)
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"

# claude code (native installer; re-run = ensure latest, self-updates after)
curl -fsSL https://claude.ai/install.sh | bash

# rust via rustup (~/.cargo/bin is already on PATH in dot_zshrc)
if command -v rustup >/dev/null 2>&1; then
  rustup update
else
  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi

# jj — prebuilt musl binary from the latest GitHub release
JJ_URL=$(curl -fsSL https://api.github.com/repos/jj-vcs/jj/releases/latest \
  | jq -r '.assets[].browser_download_url' \
  | grep "$(uname -m)-unknown-linux-musl\.tar\.gz$")
tmp=$(mktemp -d)
curl -fsSL "$JJ_URL" | tar -xz -C "$tmp"
install -m 0755 "$(find "$tmp" -name jj -type f)" "$HOME/.local/bin/jj"
rm -rf "$tmp"

# zig — latest stable tarball from ziglang.org (re-run = refresh)
ZIG_URL=$(curl -fsSL https://ziglang.org/download/index.json \
  | jq -r "to_entries | map(select(.key != \"master\")) | .[0].value.\"$(uname -m)-linux\".tarball")
tmp=$(mktemp -d)
curl -fsSL "$ZIG_URL" | tar -xJ -C "$tmp"
$SUDO rm -rf /usr/local/zig
$SUDO mv "$tmp"/zig-* /usr/local/zig
$SUDO ln -sfn /usr/local/zig/zig /usr/local/bin/zig
rm -rf "$tmp"

# neovim — official release tarball (latest; noble's apt build is 0.9.5)
case "$(uname -m)" in
  x86_64)  NVIM_ARCH="x86_64" ;;
  aarch64) NVIM_ARCH="arm64" ;;
  *) echo "debian.sh: unsupported arch for neovim: $(uname -m)" >&2; exit 1 ;;
esac
tmp=$(mktemp -d)
curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" \
  | tar -xz -C "$tmp"
$SUDO rm -rf "/opt/nvim-linux-${NVIM_ARCH}"
$SUDO mv "$tmp/nvim-linux-${NVIM_ARCH}" /opt/
$SUDO ln -sfn "/opt/nvim-linux-${NVIM_ARCH}/bin/nvim" /usr/local/bin/nvim
rm -rf "$tmp"

# tailscale (install only — NEVER `tailscale up` here: an exe.dev cp clone
# would duplicate the node identity; authenticate per-machine, by hand)
# guard on `tailscale` not `tailscaled`: /usr/sbin isn't on non-root PATH
# on Debian, which would make the guard false-negative and re-run the installer
command -v tailscale >/dev/null 2>&1 || curl -fsSL https://tailscale.com/install.sh | sh

# --- oh-my-zsh ---------------------------------------------------------------
# guard: the omz installer exits non-zero if ~/.oh-my-zsh already exists;
# KEEP_ZSHRC protects a chezmoi-applied ~/.zshrc on re-runs
[ -d "$HOME/.oh-my-zsh" ] || KEEP_ZSHRC=yes sh -c \
  "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# --- login shell -------------------------------------------------------------
$SUDO chsh -s "$(command -v zsh)" "$(id -un)"

echo "provision/debian.sh: done"
