#!/bin/sh
# operator-config.sh — render the operator's agentworks config from 1Password.
#
# OPERATOR WORKSTATION ONLY. This is the entrypoint a VM/agent never runs: it
# lives OUTSIDE chezmoi's home/ tree, so `chezmoi apply` (wire.sh) on a VM or
# exe.dev box never touches the agentworks config. Run it on your Mac to
# (re)generate ~/.config/agentworks/config.toml from agentworks-config.toml.tmpl,
# with the [proxmox] values pulled from 1Password (op://Private/homelab/proxmox-*).
#
# Re-run it whenever the template or the 1Password values change. It backs up the
# existing config first and renders atomically (temp file → move), so a failed
# inject can't clobber a working config.
set -eu

src="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
tmpl="$src/agentworks-config.toml.tmpl"
dest="${AGW_CONFIG:-$HOME/.config/agentworks/config.toml}"

command -v op >/dev/null 2>&1 || {
  echo "operator-config.sh: 1Password CLI (op) not found — install it first." >&2
  exit 1
}
op whoami >/dev/null 2>&1 || {
  echo "operator-config.sh: op is not signed in. Run 'op signin' (or homelab_env) first." >&2
  exit 1
}
[ -f "$tmpl" ] || { echo "operator-config.sh: template not found: $tmpl" >&2; exit 1; }

# Preflight: op inject resolves EVERY op:// reference in the file, not just the
# {{ }}-wrapped ones. A bare op:// (e.g. left in a comment) makes inject fail or,
# worse, resolve a bogus reference. Catch it here with a clear message.
bare="$(grep -n 'op://' "$tmpl" | grep -v '{{ op://' || true)"
if [ -n "$bare" ]; then
  echo "operator-config.sh: template has a bare op:// reference — op inject resolves ALL of them:" >&2
  echo "$bare" | sed 's/^/  /' >&2
  echo "  Wrap real refs as {{ op://... }} and remove op:// from comments/strings." >&2
  exit 1
fi

mkdir -p "$(dirname "$dest")"
if [ -f "$dest" ]; then
  bak="$dest.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  cp "$dest" "$bak"
  echo "operator-config.sh: backed up existing config → $bak"
fi

# Render to a temp file first so a failed inject can't truncate a good config.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
op inject -i "$tmpl" > "$tmp"
mv "$tmp" "$dest"
echo "operator-config.sh: wrote $dest"
echo "operator-config.sh: verify with 'agw doctor'"
