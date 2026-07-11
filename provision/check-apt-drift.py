#!/usr/bin/env python3
"""Guard against apt-list drift between debian.sh and the agentworks config.

The apt package list lives in two places on purpose: provision/debian.sh must
install it to stand alone on bare-metal / exe.dev, while the agentworks config
pre-installs the same set via `vm_template.apt` (in a roomier 300s window) so
debian.sh's copy no-ops on a VM and can't blow the 120s dotfiles window. This
is the deliberate "a little copying is better than a little dependency" trade —
and this script is the "test to ensure the copy stays in sync."

It compares debian.sh's `APT_PACKAGES` (the shared set) against the agentworks
config's `vm_templates.<name>.apt`. `APT_PACKAGES_HEAVY` (qemu) is intentionally
NOT in the config — it's bare-metal-only — so it is excluded from the check.

Usage:
  provision/check-apt-drift.py [--config PATH] [--template NAME]

Exit codes: 0 = in sync (or config absent — CI-safe skip); 1 = drift; 2 = error.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tomllib
from pathlib import Path


def parse_debian_apt(debian_sh: Path) -> set[str]:
    """Extract the APT_PACKAGES set from debian.sh (a single-line assignment)."""
    text = debian_sh.read_text()
    m = re.search(r'^APT_PACKAGES="([^"]*)"', text, re.MULTILINE)
    if not m:
        sys.exit(f"error: no `APT_PACKAGES=\"...\"` line found in {debian_sh}")
    return set(m.group(1).split())


def parse_config_apt(config: Path, template: str) -> set[str]:
    """Extract vm_templates.<template>.apt from the agentworks config."""
    with config.open("rb") as fh:
        data = tomllib.load(fh)
    tmpl = data.get("vm_templates", {}).get(template, {})
    return set(tmpl.get("apt", []))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    default_config = os.environ.get(
        "AGW_CONFIG", str(Path.home() / ".config" / "agentworks" / "config.toml")
    )
    ap.add_argument("--config", default=default_config, help="agentworks config.toml")
    ap.add_argument("--template", default="default", help="vm_templates.<name> to check")
    args = ap.parse_args()

    debian_sh = Path(__file__).resolve().parent / "debian.sh"
    if not debian_sh.is_file():
        sys.exit(f"error: {debian_sh} not found")

    config = Path(args.config)
    if not config.is_file():
        # No config here (e.g. public CI without the private operator config).
        # Nothing to drift against — skip rather than fail.
        print(f"check-apt-drift: config not found ({config}); skipping.")
        return 0

    want = parse_debian_apt(debian_sh)
    have = parse_config_apt(config, args.template)

    missing = want - have  # in debian.sh, not pre-installed by the VM
    extra = have - want     # pre-installed by the VM, not in debian.sh

    if not missing and not extra:
        print(f"check-apt-drift: in sync ({len(want)} packages).")
        return 0

    print("check-apt-drift: DRIFT between debian.sh and "
          f"vm_templates.{args.template}.apt in {config}\n")
    if missing:
        print("  in debian.sh APT_PACKAGES but MISSING from vm_template.apt")
        print("  (the VM would install these late, in the 120s window):")
        for p in sorted(missing):
            print(f"    - {p}")
    if extra:
        print("\n  in vm_template.apt but NOT in debian.sh APT_PACKAGES")
        print("  (drop them, or add to debian.sh if bare-metal needs them too):")
        for p in sorted(extra):
            print(f"    + {p}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
