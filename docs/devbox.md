# Devbox-first development on exe.dev

These dotfiles double as the bootstrap for an agentic, devbox-first workflow
on [exe.dev](https://exe.dev) — a devbox service you drive entirely over SSH
(`ssh exe.dev <command>` manages VMs; `ssh <vm>.exe.xyz` is a shell on one).
Every project gets a golden "root" VM, and every task — yours or an agent's —
gets a disposable copy-on-write fork of it, ready in seconds. No snowflake
machines, no per-task setup.

## The pattern

```text
ssh exe.dev new myproject          ← fresh VM; setup script bootstraps it
        │                            (tools + dotfiles, unattended)
        ▼
   myproject (root VM)             ← the golden base; never hand-tweaked
        │
        ├─ ssh exe.dev cp myproject task-a    ← fork for a feature branch
        ├─ ssh exe.dev cp myproject task-b    ← fork for an agent run
        └─ ssh exe.dev cp myproject task-c    ← blast radius: one box
```

- The **root VM** is built entirely by `bootstrap.sh` — if it drifts or you
  need another project, make a new one the same way and get the same machine.
- **Forks** (`cp`) inherit the root's disk — toolchain, dotfiles, working
  credentials — with zero per-clone setup. Clones can be sized differently
  (`--cpu`, `--memory`, `--disk`).
- Long-lived clones reconcile config with `chezmoi update`
  ([chezmoi](https://www.chezmoi.io) is the dotfile manager that applies
  this repo's `home/` to `$HOME`); everything else stays frozen at fork
  time, which is the point.

## One-shot bootstrap

`bootstrap.sh` turns a fresh Debian/Ubuntu box into a fully-configured
machine, unattended:

```text
bootstrap.sh
  ├─ provision/debian.sh   tools: apt packages, neovim, rust, zig, jj,
  │                        chezmoi, claude, tailscale, oh-my-zsh, chsh to zsh
  └─ chezmoi init --apply  config: this repo's home/ applied to $HOME
```

Three ways to run it:

```bash
# 1. account-wide default — every future `ssh exe.dev new` self-bootstraps
printf '#!/bin/bash\ncurl -fsLS https://raw.githubusercontent.com/n2p5/dotfiles/main/bootstrap.sh | sh\n' \
  | ssh exe.dev defaults write dev.exe new.setup-script

# 2. per-VM, at creation
printf '#!/bin/bash\ncurl -fsLS https://raw.githubusercontent.com/n2p5/dotfiles/main/bootstrap.sh | sh\n' \
  | ssh exe.dev new myproject --setup-script /dev/stdin

# 3. in place, on any existing box
ssh myproject.exe.xyz 'curl -fsLS https://raw.githubusercontent.com/n2p5/dotfiles/main/bootstrap.sh | sh'
```

exe.dev runs setup scripts as `/exe.dev/setup` once at first boot. The
stored script is a one-line shim by design ("use indirection", per the
exe.dev docs): the real logic lives in this repo and evolves with `main`,
so the account default never goes stale. Setup scripts run on `new` only —
`cp` clones inherit the already-bootstrapped disk instead, which is exactly
what you want.

Re-running `bootstrap.sh` is safe: apt no-ops on what's present, vendor
installers no-op or refresh to latest, and the chezmoi step becomes
`chezmoi update`. To verify a first boot worked, ssh in and look for
`bootstrap.sh: complete` in the setup log — or just re-run it.

## Keeping personal data out of a public repo

This repo is public and meant to be shared. The pattern keeps personal
material off it by construction:

- **Host-specific and secret config lives in unmanaged files** —
  `~/.zshrc.local` and `~/.env` are sourced by the managed `.zshrc` if they
  exist, but are never tracked here. Anything machine- or employer-specific
  goes there, by hand, per machine.
- **No tokens, ever.** On exe.dev, GitHub auth comes from their GitHub App
  integration (an in-VM proxy injects credentials; nothing is stored on
  disk, and it survives `cp`). Elsewhere, `gh auth login` per machine.
- **Tailscale is installed but never authenticated by the bootstrap.**
  A `tailscale up` baked into the root VM would clone the node identity
  into every fork. Authenticate per-machine, by hand, if and when needed.
- **VM names and infrastructure details stay out of the repo.** The
  bootstrap is machine-agnostic; nothing here encodes where it runs.

## Make it yours

Fork the repo, replace `n2p5/dotfiles` with your own in `bootstrap.sh` and
the commands above, put your config under `home/` (chezmoi naming:
`dot_zshrc` → `~/.zshrc`), and adjust the tool list in
`provision/debian.sh`. macOS tooling is the same idea via
`brew bundle --file=provision/Brewfile`.
