# Dotfiles + Tooling Bootstrap — Design Spec

- **Date:** 2026-05-27
- **Repo:** `github.com/n2p5/dotfiles`
- **Status:** Approved 2026-05-27; **partially superseded — read the Update below before the body.**

## Update — 2026-06-07 (revised during incremental implementation)

The body below remains the north-star reference, but several decisions changed as the design was built incrementally. **Where this update conflicts with the body, this update wins.**

- **Reframing.** The setup is personal-first and simple; agentworks and exe.dev are contexts it must run under *without breaking their assumptions* — not the purpose. The "agentworks is the forcing function" framing (Background, D1) is softened: chezmoi is simply a better personal tool than the bare repo and *also* yields a clean `install.sh` seam. exe.dev is just an SSH box, not a modeled target.
- **Two layers, separated (revises D4).** chezmoi does **not** orchestrate tool installation. `home/` is the chezmoi source = **configuration only**. A sibling `provision/` at the repo root (outside `home/`, invisible to chezmoi) is the **provisioning layer** = tools (`provision/Brewfile` now; a mise manifest later). The bootstrap orchestrates provisioning and chezmoi as *peers*. On agent machines, agentworks already **is** the provisioning layer (it owns apt and runs `mise install` from a lockfile), so the dotfiles never install system packages there.
- **Dropped: the `kind` taxonomy and all `.chezmoi.toml.tmpl` prompts.** OS branching comes from chezmoi's auto-detected `.chezmoi.os`; there are no `personal`/`vm`/`agent` modes and no interactive prompts (which keeps the agentworks seam non-interactive for free).
- **The run-script ladder mostly evaporates.** mise / brew / apt / Claude Code installs move to `provision/`; only genuine user-config setup (e.g. oh-my-zsh) would remain as a chezmoi `run_` script. The reserved `30` skills slot is dropped.
- **Source-location model.** chezmoi's default `~/.local/share/chezmoi` is the real source on every machine (canonical `chezmoi init n2p5/dotfiles`); an optional `~/src/github.com/n2p5/dotfiles` symlink preserves the `~/src` convention. Never make chezmoi's source dir itself a symlink.
- **Delivery is incremental** — the spec is a reference, not a checklist; rungs are added only when a concrete need appears.
  - Increment 1 ✅ (PR #1) — retire the bare repo; chezmoi manages existing config (`.chezmoiroot` → `home/`).
  - Increment 2 ✅ (PR #2) — `provision/Brewfile`, the curated Mac tool manifest.
- **Still open / deferred:** mise lockfile filename + enable flag (OQ#2); a `make provision` / `bootstrap.sh` runner; macOS `defaults`; the `install.sh` shim; the skills subsystem.

## Summary

Redesign `n2p5/dotfiles` so a single repo can bootstrap a complete development environment on three targets — the author's macOS machine, agentworks-managed Debian VMs, and exe.dev cloud environments — and stay reconcilable on every machine via one verb (`chezmoi update`). The current bare-repo approach (`git --git-dir=$HOME/.dotfiles --work-tree=$HOME`) is retired in favor of a normal repo whose root carries an `install.sh` bootstrap shim and whose `home/` subdirectory is a chezmoi source tree.

Two tools split responsibilities cleanly:

- **mise** owns pinned, reproducible toolchains (languages and dev CLIs).
- **chezmoi** owns everything else — file placement, per-OS scripted installs, system configuration, and reconciliation.

A separate `n2p5/skills` repo will follow Matt Pocock's pattern (Claude Code plugin manifest + symlink-into-`~/.claude/skills` author loop). Its implementation is **deferred** until the skills repo has its first real skill; the design is captured here verbatim so the follow-up has no design work left to do.

## Goals

- One repo bootstraps a fresh machine to a known good state.
- One reconciliation verb (`chezmoi apply` / `chezmoi update`) keeps any existing machine current.
- Works on macOS, agentworks Debian VMs, and exe.dev without per-target forks of the bootstrap.
- Generic configuration is committed; host-specific and secret material stays unmanaged on disk.
- Compatible with agentworks' `dotfiles_install_cmd` contract: `cd ~/.dotfiles && ./install.sh`, 120 s timeout, non-fatal failure.
- Additive growth: adding a new tool, a new OS-specific package, or a new skill is a small, local change.

## Non-goals

- Managing project-level `CLAUDE.md` or per-project `.claude/`.
- Managing secrets via a password manager or `age` (chezmoi supports it; deferred).
- System services, daemons, or anything requiring root that mise/Homebrew/apt don't already model.
- Windows support.

## Background

### Current state

The repo at `~/src/github.com/n2p5/dotfiles` currently ships:

```text
.zshrc                  # oh-my-zsh, plugin list, PATH, sources .shell_functions / .zshrc.local / .env
.shell_functions        # aws_env helper
.tmux.conf              # Ctrl-A prefix, vi-mode, cross-platform clipboard
.config/nvim/init.lua
.gitignore              # ignore-everything + allowlist (bare-repo idiom)
```

`.zshrc:21` defines `alias ddot='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'`. The live system uses the bare-repo technique with `$HOME` as the work tree.

### The forcing function

agentworks (`agentworks-cli==0.2.1`, installed at `~/.local/pipx/venvs/agentworks-cli/`) expects:

```toml
dotfiles_source = "git::https://github.com/user/dotfiles"
dotfiles_destination = "~/.dotfiles"
dotfiles_install_cmd = "./install.sh"
```

At init and reinit, it runs `cd ~/.dotfiles && ./install.sh` with a 120 s timeout, as the target user; failures log a warning and are non-fatal. (See `agentworks/vms/initializer.py:1222-1237` and `agentworks/agents/manager.py:682-762`.)

The bare-repo model has no `install.sh` and cannot satisfy this contract. Conversion to a normal repo with a root `install.sh` is required.

agentworks also natively consumes `mise_lockfile` *after* applying dotfiles, so the dotfiles repo can ship a lockfile that agentworks uses verbatim.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Retire the bare-repo approach; convert to a normal git repo. | Required by agentworks' `./install.sh` contract. |
| D2 | Use **chezmoi** as the dotfile manager. | First-class idempotency (`run_once_` / `run_onchange_`, externals, templates) and clean per-machine variance via `.chezmoi.toml`. |
| D3 | Use **mise** for reproducible toolchains; use chezmoi `run_*` scripts for everything else. | Different problem shapes deserve different tools. mise's lockfile gives reproducibility where it matters; run scripts handle self-updating apps and OS-specific installers without pretending to be a version manager. |
| D4 | **chezmoi orchestrates** the whole bootstrap; `install.sh` is a ~20-line shim that ensures chezmoi exists and hands off. | Single reconciliation verb; idempotency state owned in one place; agentworks and Mac entry points converge at `chezmoi apply`. |
| D5 | Install **Claude Code via its native installer** from a `run_once_after_` script, not via mise. | The native installer is self-updating; pinning it under mise creates a fight with its background updater. Behavior is steered via `~/.claude/settings.json` (`autoUpdatesChannel`, `minimumVersion`, optional `DISABLE_AUTOUPDATER`). |
| D6 | Generic config in repo; host-specific/secret material in **unmanaged** `~/.zshrc.local` and `~/.env`, sourced by the managed `dot_zshrc`. | Matches the user's existing model; keeps the public repo private-safe. |
| D7 | Skills follow Matt Pocock's pattern in a separate `n2p5/skills` repo (plugin manifest + chezmoi external + symlink loop). | Author live, distribute as a plugin, same repo serves both. |
| D8 | Skills subsystem implementation is **deferred** to a follow-up. Design captured below. | YAGNI; avoids dead-code wiring for an empty repo. |

## Architecture

### Two entry points, one convergence point

```text
Fresh Mac:     sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply n2p5/dotfiles
                   └─ chezmoi self-installs → clones repo → reads home/ → apply

agentworks /   git clone → cd ~/.dotfiles → ./install.sh
exe.dev:           └─ shim ensures chezmoi exists → chezmoi init --apply --source $PWD

                              ▼ both run the same ladder ▼
   1. run_once_before  10-install-mise        (bootstrap mise)
   2. (apply files)    dot_zshrc, dot_tmux.conf, dot_claude/*, mise config…
   3. run_onchange     20-mise-install        (pinned toolchains)
   4. run_once_after   40-oh-my-zsh           (omz + plugins)
   5. run_once_after   50-os-packages         (Brewfile on darwin; apt on linux)
   6. run_once_after   60-claude-code         (native installer, channel from settings)
   7. run_once_after   70-macos-defaults      (defaults write, darwin-only)
```

Re-running forever on any machine is `chezmoi update` (pull + apply + re-run anything changed).

### Repo topology

```text
dotfiles/                          # cloned to ~/.dotfiles by agentworks;
│                                  # cloned to ~/.local/share/chezmoi on Mac
├── install.sh                     # bootstrap shim (entry point for agentworks/exe.dev)
├── .chezmoiroot                   # contains: home
├── README.md  .github/  LICENSE
├── docs/superpowers/specs/...     # this spec, plus future plans
└── home/                          # ← chezmoi source dir
    ├── .chezmoi.toml.tmpl         # prompts on init → kind, git name/email
    ├── .chezmoiignore             # exclude ~/.zshrc.local, ~/.env, README, etc.
    ├── dot_zshrc                  # → ~/.zshrc   (sources ~/.zshrc.local & ~/.env)
    ├── dot_tmux.conf  dot_shell_functions
    ├── dot_config/
    │   ├── nvim/init.lua
    │   ├── mise/config.toml.tmpl  # universal tooling manifest
    │   └── dotfiles/
    │       ├── macos.Brewfile
    │       ├── macos.defaults.sh
    │       └── linux.apt.list
    ├── dot_claude/
    │   ├── CLAUDE.md              # global system prompt
    │   └── settings.json.tmpl     # global Claude Code settings
    ├── run_once_before_10-install-mise.sh.tmpl
    ├── run_onchange_after_20-mise-install.sh.tmpl
    ├── run_once_after_40-oh-my-zsh.sh.tmpl
    ├── run_once_after_50-os-packages.sh.tmpl
    ├── run_once_after_60-claude-code.sh.tmpl
    └── run_once_after_70-macos-defaults.sh.tmpl
```

### The chezmoi ⇄ mise split

| Concern | Tool | Why |
|---|---|---|
| Languages, dev CLIs (`go`, `node`, `python`, `rust`, `bun`, `uv`, `ripgrep`, `fzf`, `jq`, `gh`, `jj`, `neovim`, `chezmoi` itself) | **mise** | Versions matter; lockfile is reproducible; agentworks reads the same lockfile |
| Claude Code | **chezmoi `run_once_`** (native installer) | Self-updating app; pinning fights its updater |
| Homebrew + Brewfile (casks, fonts, mas apps) on macOS | **chezmoi `run_once_`** | macOS-native; brew is the idiomatic registry |
| Linux non-agentworks system packages | **chezmoi `run_once_`** | OS-specific; agentworks owns apt for its VMs |
| macOS system prefs (`defaults write …`) | **chezmoi `run_once_`** | Inherently OS-specific; no version concept |
| oh-my-zsh + zsh plugins | **chezmoi `run_once_`** | Has its own installer + `omz update` |

## Components

### `install.sh` (bootstrap shim)

Lives at the repo root. Contract: agentworks runs `cd ~/.dotfiles && ./install.sh` as the target user, with a 120 s timeout, treating non-zero exits as warnings.

Behavior, in order:

1. `set -euo pipefail`.
2. Detect OS via `uname -s`.
3. Ensure `chezmoi` is on `PATH`; if not, install it via `get.chezmoi.io` into `~/.local/bin`.
4. `chezmoi init --source "$(cd "$(dirname "$0")" && pwd)" --apply` — initializes chezmoi pointing at this checkout (so `.chezmoiroot=home` is honored) and applies in one shot.
5. Exit with whatever `chezmoi apply` returns.

Target: ~20 lines of POSIX `sh`, no exotic dependencies.

### chezmoi source layout

Source root is `home/` via `.chezmoiroot`. Standard chezmoi naming:

- `dot_X` → `~/.X`
- `dot_X.tmpl` → `~/.X` after Go-template evaluation
- `private_dot_X` for files that should be mode-600
- Special files (`.chezmoiignore`, `.chezmoiexternal.*`, `.chezmoi.toml.tmpl`, all `run_*` scripts) live **inside** `home/`

### `.chezmoi.toml.tmpl` (prompt-on-init)

Prompts on first `chezmoi init` for:

- `kind` — `personal` (your Mac), `vm` (agentworks/exe.dev), or `agent` (agentworks isolated agent users)
- `gitName`, `gitEmail` — for templates that need them
- `claudeCodeChannel` — `stable` (default) or `latest`

Values are stored in chezmoi's config and available as `{{ .kind }}` etc. in any template.

### mise tooling manifest

`home/dot_config/mise/config.toml.tmpl` → `~/.config/mise/config.toml`. Declares pinned `tool@version` entries.

Initial scope (refined during implementation):

- Languages: `go`, `node`, `python`, `rust`, `bun`, `uv`
- CLIs: `ripgrep`, `fzf`, `jq`, `gh`, `jj`, `neovim`, `chezmoi`

Lockfile is committed and pointed at by agentworks' `mise_lockfile`. The exact lockfile filename and enable-flag will be pinned against current mise docs at implementation time rather than guessed here.

### Run-script ladder

Ordering by numeric prefix. OS branching via `{{ .chezmoi.os }}`; kind-gating via `{{ .kind }}`. Every script: `set -euo pipefail`, idempotent, fails loudly.

| Script | Type | Purpose |
|---|---|---|
| `10-install-mise.sh.tmpl` | `run_once_before_` | Install mise via official installer if missing |
| `20-mise-install.sh.tmpl` | `run_onchange_after_` | `mise install` from the manifest; no-op when satisfied. Re-fires when the manifest changes (we template a hash of it into the script header) |
| `40-oh-my-zsh.sh.tmpl` | `run_once_after_` | omz installer; install zsh plugins listed in `dot_zshrc` |
| `50-os-packages.sh.tmpl` | `run_once_after_` | `darwin`: `brew bundle --file=~/.config/dotfiles/macos.Brewfile`. `linux` *and* `kind != vm`: apply `~/.config/dotfiles/linux.apt.list`. (On agentworks VMs, apt is owned by agentworks' catalog, so this branch is skipped.) |
| `60-claude-code.sh.tmpl` | `run_once_after_` | `curl -fsSL https://claude.ai/install.sh \| bash -s {{ .claudeCodeChannel }}` |
| `70-macos-defaults.sh.tmpl` | `run_once_after_` | `darwin` only; applies `~/.config/dotfiles/macos.defaults.sh`. Skipped if the file is empty |

Re-run semantics: `run_onchange_` re-fires when the rendered script content changes; `run_once_` runs once per unique content hash and again if it previously failed. ([chezmoi scripts docs](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/))

The numeric prefix `30` is intentionally skipped — reserved for the deferred `run_onchange_30-link-skills.sh.tmpl` (see the skills subsystem section). When that lands, it slots in between `mise-install` and `oh-my-zsh` without renumbering anything.

#### Note on the 120 s agentworks budget

The 20-mise-install script may exceed 120 s on a *fresh* VM if many toolchains are pinned. We accept this: agentworks treats the failure as non-fatal *and* runs its own `mise install` step from the same lockfile right after, which is the authoritative backstop. On subsequent reinits, mise install is a fast no-op. We do not try to outrun the budget.

### `dot_claude/`

- `dot_claude/CLAUDE.md` → `~/.claude/CLAUDE.md`. Global system prompt; same on every machine that's you.
- `dot_claude/settings.json.tmpl` → `~/.claude/settings.json`. Templated for:
  - `autoUpdatesChannel` — `"stable"` by default; `"latest"` if `kind == personal` and the user opts in.
  - `minimumVersion` — optional floor.
  - `env.DISABLE_AUTOUPDATER` — set to `"1"` only if Claude is pinned via mise (alternative not chosen as default).

Not managed here: `~/.claude/skills/` (future skills subsystem) and `~/.claude/plugins/` (Claude Code owns this directory).

### Layering: generic / per-machine / host-specific

| Tier | Lives where | Managed? |
|---|---|---|
| Generic | repo `home/` | chezmoi (committed) |
| Per-machine, non-secret | repo, templated | chezmoi templates, branched on `kind` / `.chezmoi.os` |
| Host-specific or secret | `~/.zshrc.local`, `~/.env` | **unmanaged**; listed in `.chezmoiignore`; sourced by `dot_zshrc` |

`dot_zshrc` ends with:

```bash
[[ -f ~/.shell_functions ]] && source $HOME/.shell_functions
[[ -f ~/.zshrc.local ]] && source $HOME/.zshrc.local
[[ -f ~/.env ]] && source $HOME/.env
```

The `ddot` alias from `.zshrc:21` is removed.

## Data flow

### Fresh-machine bootstrap (Mac)

```text
$ sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply n2p5/dotfiles
  ├─ chezmoi binary downloaded to ~/.local/bin/chezmoi
  ├─ git clone n2p5/dotfiles → ~/.local/share/chezmoi
  ├─ reads .chezmoiroot → switches source to home/
  ├─ reads .chezmoi.toml.tmpl → prompts for kind, gitName, gitEmail, claudeCodeChannel
  ├─ computes target state from source state + data + templates
  └─ apply phase, in order:
       run_once_before_10-install-mise     → mise on PATH
       write dot_* files                    (zshrc, tmux.conf, claude/, mise config, …)
       run_onchange_after_20-mise-install  → languages + CLIs installed
       run_once_after_40-oh-my-zsh         → omz + plugins
       run_once_after_50-os-packages       → brew + Brewfile (darwin branch)
       run_once_after_60-claude-code       → claude installed
       run_once_after_70-macos-defaults    → defaults applied
```

### agentworks VM init / reinit

```text
agentworks vm init|reinit
  ├─ (already provisioned: openssh, sudo, git, tmux, tmuxinator, acl, jq, unzip)
  ├─ git clone n2p5/dotfiles → ~/.dotfiles
  ├─ cd ~/.dotfiles && ./install.sh        (120 s timeout, non-fatal)
  │    └─ ensures chezmoi → chezmoi init --source ~/.dotfiles --apply
  │         ├─ kind = vm
  │         ├─ apply files
  │         ├─ run scripts (20-mise-install may be clipped on first init)
  │         └─ claude-code installed
  ├─ agentworks's own mise step runs `mise install` from our lockfile  (backstop)
  └─ agentworks's agent-user setup runs each agent's dotfiles step
```

## Skills subsystem — DEFERRED to a follow-up

Captured here for the follow-up implementation. **Not implemented in this iteration:** no `.chezmoiexternal.toml.tmpl`, no `run_onchange_30-link-skills.sh.tmpl`, no `.claude-plugin/plugin.json` in `n2p5/skills` yet. The `n2p5/skills` repo exists but only has `LICENSE` + `.gitignore`.

### The pattern

```text
                  ┌─────────────────────────────────────────┐
                  │   github.com/n2p5/skills   (public)     │
                  │   ├ .claude-plugin/plugin.json          │
                  │   ├ skills/<category>/<name>/SKILL.md   │
                  │   ├ scripts/  CLAUDE.md  CONTEXT.md     │
                  │   └ docs/adr/                            │
                  └─────────────────────────────────────────┘
                              ▲                       ▲
              consumer-path   │                       │ author-path
              (any machine)   │                       │ (your machines)
                              │                       │
              Claude Code     │                       │ chezmoi external
              plugin install  │                       │ (git-repo, weekly pull)
                              │                       ▼
                              │                ~/src/github.com/n2p5/skills
                              │                  (a real, pushable clone)
                              │                       │
                              │                       │ run_onchange_30-link-skills
                              │                       ▼
                              └──────────────►   ~/.claude/skills/<name>
                                                  (symlinks; flat)
```

### Skills repo layout (`n2p5/skills`)

```text
skills/
  engineering/    diagnose/  triage/  ...
  productivity/   grill-me/  write-a-skill/  ...
  misc/           git-guardrails/  setup-pre-commit/  ...
  personal/       (publishable-but-personal skills)
  in-progress/    (excluded from linking)
  deprecated/     (excluded from linking)
.claude-plugin/plugin.json   # explicit skills array — consumer install path
scripts/link-skills.sh       # author-side helper for non-chezmoi users
CLAUDE.md  CONTEXT.md  docs/adr/   # methodology, grown over time
```

Private/work-only skills do not belong in this public repo. When the need arises, add a second private repo (e.g. `n2p5/skills-private`) as another chezmoi external — same machinery, separate visibility. Do not build now.

### The chezmoi external (future addition to `home/.chezmoiexternal.toml.tmpl`)

```toml
["src/github.com/n2p5/skills"]
  type = "git-repo"
  url = "https://github.com/n2p5/skills.git"
  refreshPeriod = "168h"
  [".../clone"]
    args = ["--filter=blob:none"]
  [".../pull"]
    args = ["--ff-only"]
```

Target path `~/src/github.com/n2p5/skills` matches the existing src layout (this dotfiles repo lives at `~/src/github.com/n2p5/dotfiles`). The clone is a real pushable working tree; chezmoi just `git pull --ff-only`s it on refresh. ([chezmoi externals docs](https://www.chezmoi.io/reference/special-files/chezmoiexternal-format/))

### The link script (future `run_onchange_after_30-link-skills.sh.tmpl`)

Mirrors Matt Pocock's `scripts/link-skills.sh` with two upgrades:

1. **Re-runs whenever skills change**, not just when the script changes — template the current commit of the skills clone into a header comment so a new commit upstream changes the rendered script content and chezmoi re-fires it:

   ```bash
   # skills-rev: {{ output "git" "-C" (joinPath .chezmoi.homeDir "src/github.com/n2p5/skills") "rev-parse" "HEAD" | trim }}
   ```

2. **Prunes stale symlinks** — any `~/.claude/skills/*` symlink that no longer resolves into the skills clone gets removed.

Otherwise: iterate `skills/<category>/<name>/SKILL.md`, exclude `deprecated/` and `in-progress/`, `ln -sfn` each into `~/.claude/skills/<name>` (flat), guard against circular links.

### Authoring loop (future)

```bash
cd ~/src/github.com/n2p5/skills
mkdir -p skills/engineering/my-new-skill && $EDITOR skills/engineering/my-new-skill/SKILL.md
chezmoi apply             # link script re-fires; ~/.claude/skills/my-new-skill appears
git add -A && git commit -m "add my-new-skill" && git push
```

On any other machine: `chezmoi update` → external pulls → link script re-fires → new symlinks appear.

## Idempotency

- chezmoi tracks `run_*` script state in its persistent state; `run_onchange_` re-fires only when content changes, `run_once_` runs once per unique content hash and again if it previously failed.
- Each script is internally idempotent regardless: `mise install` is a no-op when satisfied, oh-my-zsh's installer guards itself, the Claude Code native installer is safe to re-run, `brew bundle` is idempotent, symlinks use `ln -sfn`.
- `chezmoi apply` and `chezmoi update` are the universal "make it match" verbs on every machine, every time.

## Error handling

- Every run script uses `set -euo pipefail` and fails loudly locally — silent corruption is the enemy.
- On agentworks VMs, `./install.sh` is non-fatal by agentworks' contract; a partial chezmoi apply does not brick the VM. agentworks' own subsequent mise step is the backstop for the heavy `mise install`.
- The 120 s timeout: the *first* run on a fresh VM may be clipped; agentworks completes the install separately. We accept "slow on first init, instant after."
- chezmoi has a sanity layer: `chezmoi doctor`, `chezmoi diff`, `chezmoi verify`. We do not add more.

## Testing

- **`chezmoi diff`** and **`chezmoi apply --dry-run`** for fast local validation before every change.
- **`chezmoi execute-template`** to lint templates against your data.
- **A Linux container** (`debian:12` and optionally `ubuntu:24.04`) running `./install.sh` end-to-end — runnable via a `Makefile` target (`make test-bootstrap`) and optionally a GitHub Action on push. This is what catches regressions you'd otherwise discover on a real fresh VM.
- **macOS testing** is on the author's actual machine — there is no honest containerized macOS, so we rely on `chezmoi diff` + small, reversible changes.

## Migration plan

Six steps, reversible until step 5:

1. **Back up the current state**: `cp -a ~/.dotfiles ~/.dotfiles.bak.$(date +%Y%m%d)` (the bare git dir), plus a snapshot of each currently-managed file in `$HOME` (`.zshrc`, `.tmux.conf`, `.shell_functions`, `.config/nvim/init.lua`).
2. **Restructure this repo in place**: add `.chezmoiroot` containing `home`; move existing files into `home/` under chezmoi naming (`.zshrc` → `home/dot_zshrc`, etc.); add the new run scripts and `.chezmoi.toml.tmpl`; replace the bare-repo `.gitignore` with a normal one.
3. **Push** the new layout to `github.com/n2p5/dotfiles`.
4. **Bootstrap on the Mac**:

   ```bash
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init n2p5/dotfiles   # no --apply yet
   chezmoi diff                                                # preview every change
   chezmoi apply
   ```

5. **Retire the bare repo**: verify `grep ddot ~/.zshrc` returns nothing (step 2's new `dot_zshrc` omits the alias, so step 4's `chezmoi apply` already removed it), then `rm -rf ~/.dotfiles` (the old bare git dir — frees the path so agentworks can use it as its `dotfiles_destination`).
6. **Verify**: `claude --version`, `mise list`, fresh shell loads, `chezmoi verify`. If anything is wrong, restore from step 1's backup and iterate.

After that, the fresh-machine story is:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply n2p5/dotfiles
```

…and the agentworks/exe.dev story is whatever those tools already do — clone the repo and run `./install.sh`.

## Out of scope (this iteration)

- The skills subsystem (deferred per D8; design captured above).
- Managed secrets via chezmoi + password manager / `age`.
- Per-project `CLAUDE.md` / `.claude/`.
- Windows support.

## Open questions

1. **Brewfile contents** — initial scope to be decided during implementation; start minimal (1Password CLI, fonts, anything mise cannot supply) and grow on demand.
2. **mise lockfile filename + enable flag** — pin against current mise docs at implementation time; not guessed here.
3. **Claude Code channel default** — `stable` proposed; revisit if `latest` is preferred.

## References

- [chezmoi externals](https://www.chezmoi.io/reference/special-files/chezmoiexternal-format/)
- [chezmoi scripts](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/)
- [chezmoi application order](https://www.chezmoi.io/reference/application-order/)
- [Claude Code setup](https://code.claude.com/docs/en/setup)
- [mise registry](https://mise.jdx.dev/registry.html)
- [mattpocock/skills](https://github.com/mattpocock/skills) — the pattern this design follows for skills
- agentworks dotfiles contract: `agentworks/vms/initializer.py:1222-1237`, `agentworks/agents/manager.py:682-762` in `agentworks-cli==0.2.1`
