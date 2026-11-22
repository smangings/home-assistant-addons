#!/usr/bin/env python3
"""Checks that need no network or Docker. Run from the repo root.

  check-addons.py pins                 shared/Dockerfile ARG defaults match shared/build.yaml
  check-addons.py versions <base-ref>  every changed add-on bumps its version and changelog
  check-addons.py build-args <addon> <arch>
                                       print the docker build arguments for one add-on/arch

Supervisor builds with build.yaml's args, so a stale Dockerfile default goes
unnoticed until someone builds by hand. The image only rebuilds on a user's
HA when config.yaml's version moves.
"""
import re
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path.cwd()
FLOATING_BASE = re.compile(r":(bookworm|trixie|latest|stable)$")


def addons():
    return sorted(p.parent.name for p in ROOT.glob("*/config.yaml"))


def load(path):
    return yaml.safe_load(Path(path).read_text())


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def error(msg):
    print(f"::error::{msg}")


def check_pins():
    build = load("shared/build.yaml")
    args = {k: str(v) for k, v in (build.get("args") or {}).items()}
    defaults = dict(re.findall(r"^ARG\s+(\w+)=(\S*)", Path("shared/Dockerfile").read_text(), re.M))
    failed = False

    for key, value in args.items():
        if key not in defaults:
            error(f"shared/Dockerfile has no 'ARG {key}=' for build.yaml arg {key}")
            failed = True
        elif defaults[key] != value:
            error(f"{key}: build.yaml says {value}, shared/Dockerfile defaults to {defaults[key]}")
            failed = True

    base = build["build_from"]["amd64"]
    if defaults.get("BUILD_FROM") != base:
        error(f"BUILD_FROM: build.yaml amd64 is {base}, shared/Dockerfile defaults to {defaults.get('BUILD_FROM')}")
        failed = True

    for arch, image in build["build_from"].items():
        if FLOATING_BASE.search(image):
            print(f"::warning::{arch} base image {image} is a floating tag; pin a base version")

    if not failed:
        print(f"ok: {len(args)} build.yaml args match shared/Dockerfile")
    return failed


def check_versions(base_ref):
    merge_base = git("merge-base", base_ref, "HEAD").strip()
    changed = git("diff", "--name-only", merge_base, "HEAD").split()
    failed = False

    for addon in addons():
        # Docs and the changelog show from the repo directly; anything else needs a rebuild.
        docs = {f"{addon}/{name}" for name in ("CHANGELOG.md", "DOCS.md", "README.md")}
        touched = [f for f in changed if f.startswith(f"{addon}/") and f not in docs]
        if not touched:
            continue
        bad = False
        new = str(load(f"{addon}/config.yaml")["version"])
        try:
            old = str(yaml.safe_load(git("show", f"{merge_base}:{addon}/config.yaml"))["version"])
        except subprocess.CalledProcessError:
            old = None  # new add-on
        if new == old:
            error(f"{addon}: files changed but config.yaml version is still {new}. "
                  "Supervisor won't offer the update.")
            bad = True
        changelog = Path(f"{addon}/CHANGELOG.md")
        if not changelog.exists() or not re.search(rf"^## {re.escape(new)}\s*$", changelog.read_text(), re.M):
            error(f"{addon}: CHANGELOG.md has no '## {new}' entry")
            bad = True
        if not bad:
            print(f"ok: {addon} {old} -> {new}")
        failed = failed or bad
    return failed


def build_args(addon, arch):
    build = load(f"{addon}/build.yaml")
    out = ["--build-arg", f"BUILD_FROM={build['build_from'][arch]}", "--build-arg", f"BUILD_ARCH={arch}"]
    for key, value in (build.get("args") or {}).items():
        out += ["--build-arg", f"{key}={value}"]
    print("\n".join(out))
    return False


if __name__ == "__main__":
    cmd, rest = sys.argv[1], sys.argv[2:]
    failed = {"pins": check_pins, "versions": check_versions, "build-args": build_args}[cmd](*rest)
    sys.exit(1 if failed else 0)
