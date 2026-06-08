# dotfiles
my dotfiles for a cozy terminal

## Intended use

Personal dotfiles for bringing a known-good environment to any machine that's mine — macOS, agentworks-managed VMs, and exe.dev — without per-target forks. **Configuration** lives under `home/`, managed by [chezmoi](https://www.chezmoi.io) (bootstrap with `chezmoi init --apply n2p5/dotfiles`, reconcile any time with `chezmoi update`); **tooling** is a separate provisioning layer under `provision/` (e.g. `brew bundle --file=provision/Brewfile`).
