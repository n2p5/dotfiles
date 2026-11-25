# dotfiles

my dotfiles for a cozy terminal

## Intended use

Personal dotfiles for bringing a known-good environment to any machine that's mine. **Configuration** lives under `home/`, managed by [chezmoi](https://www.chezmoi.io) — bootstrap a machine with `chezmoi init --apply n2p5/dotfiles`, reconcile any time with `chezmoi update`. **Tooling** is declared for [mise](https://mise.jdx.dev) in `home/dot_config/mise/config.toml` (installed by `provision/tools.sh`, or `mise run tools` from the checkout); `provision/` keeps only the system packages mise can't provide (`debian.sh` for apt, `Brewfile` for macOS).

These dotfiles also power an agentic, devbox-first workflow on [exe.dev](https://exe.dev) — golden root VMs, disposable copy-on-write forks per task. See [docs/devbox.md](../docs/devbox.md).
