#!/usr/bin/env python3
from __future__ import annotations

import argparse
import fcntl
import json
import os
import stat
import sys
import tempfile
from pathlib import Path
from typing import Any


class ReconcileError(RuntimeError):
    pass


def load_manifest(path: Path, *, missing_ok: bool) -> dict[str, Any]:
    if not path.exists():
        if missing_ok:
            return {"version": 1, "links": {}}
        raise ReconcileError(f"manifest does not exist: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ReconcileError(f"cannot read manifest {path}: {exc}") from exc
    return validate_manifest(data, str(path))


def validate_manifest(data: Any, label: str) -> dict[str, Any]:
    if not isinstance(data, dict) or data.get("version") != 1:
        raise ReconcileError(f"{label}: expected manifest version 1")
    links = data.get("links")
    if not isinstance(links, dict):
        raise ReconcileError(f"{label}: links must be an object")

    targets: set[str] = set()
    for name, entry in links.items():
        if not isinstance(name, str) or not name:
            raise ReconcileError(f"{label}: link names must be non-empty strings")
        if not isinstance(entry, dict):
            raise ReconcileError(f"{label}: {name} must be an object")
        target = entry.get("target")
        link_target = entry.get("linkTarget")
        if not isinstance(target, str) or not os.path.isabs(target) or target == "/":
            raise ReconcileError(f"{label}: {name}.target must be an absolute non-root path")
        if not isinstance(link_target, str) or not os.path.isabs(link_target):
            raise ReconcileError(f"{label}: {name}.linkTarget must be absolute")
        adopt_existing = entry.get("adoptExistingSymlink", False)
        if not isinstance(adopt_existing, bool):
            raise ReconcileError(f"{label}: {name}.adoptExistingSymlink must be boolean")
        if target in targets:
            raise ReconcileError(f"{label}: duplicate target {target}")
        targets.add(target)
    return data


def by_target(manifest: dict[str, Any]) -> dict[str, dict[str, str]]:
    return {entry["target"]: entry for entry in manifest["links"].values()}


def check_allowed_targets(desired: dict[str, Any]) -> None:
    prefixes = desired.get("allowedTargetPrefixes", [])
    if not isinstance(prefixes, list) or not prefixes:
        raise ReconcileError("desired manifest must provide allowedTargetPrefixes")
    normalized = []
    for prefix in prefixes:
        if not isinstance(prefix, str) or not os.path.isabs(prefix) or prefix == "/":
            raise ReconcileError(f"invalid allowed target prefix: {prefix!r}")
        normalized.append(prefix.rstrip("/"))

    for entry in desired["links"].values():
        target = entry["target"]
        if not any(target == prefix or target.startswith(f"{prefix}/") for prefix in normalized):
            raise ReconcileError(f"target is outside allowed prefixes: {target}")


def ensure_safe_parent(target: str) -> None:
    parent = Path(target).parent
    current = Path(parent.anchor)
    for component in parent.parts[1:]:
        current /= component
        try:
            mode = os.lstat(current).st_mode
        except FileNotFoundError as exc:
            raise ReconcileError(f"target parent does not exist: {current}") from exc
        if stat.S_ISLNK(mode):
            raise ReconcileError(f"refusing symlink in target parent path: {current}")
        if not stat.S_ISDIR(mode):
            raise ReconcileError(f"target parent component is not a directory: {current}")


def current_symlink_target(path: str) -> str | None:
    if not os.path.lexists(path):
        return None
    if not os.path.islink(path):
        raise ReconcileError(f"refusing to replace non-symlink target: {path}")
    return os.readlink(path)


def remove_stale(target: str, old_link_target: str, *, dry_run: bool) -> None:
    if not os.path.lexists(target):
        return
    if not os.path.islink(target):
        print(f"managed-links: leaving user-owned non-symlink at stale target {target}", file=sys.stderr)
        return
    actual = os.readlink(target)
    if actual != old_link_target:
        print(
            f"managed-links: leaving modified stale symlink {target} -> {actual}",
            file=sys.stderr,
        )
        return
    print(f"managed-links: remove stale {target} -> {actual}")
    if not dry_run:
        os.unlink(target)


def install_link(
    target: str,
    link_target: str,
    old_entry: dict[str, Any] | None,
    adopt_existing_symlink: bool,
    *,
    dry_run: bool,
) -> None:
    ensure_safe_parent(target)

    actual = current_symlink_target(target)
    if actual == link_target:
        return
    if actual is not None:
        owned_target = old_entry["linkTarget"] if old_entry is not None else None
        first_adoption = old_entry is None and adopt_existing_symlink
        if actual != owned_target and not first_adoption:
            raise ReconcileError(f"refusing to replace unmanaged symlink {target} -> {actual}")
        print(f"managed-links: update {target}: {actual} -> {link_target}")
        if dry_run:
            return
        # Recheck immediately before replacement so a user change is not silently lost.
        if not os.path.islink(target) or os.readlink(target) != actual:
            raise ReconcileError(f"target changed during activation: {target}")
        temporary = f"{target}.managed-links-{os.getpid()}"
        created_temporary = False
        try:
            os.symlink(link_target, temporary)
            created_temporary = True
            os.replace(temporary, target)
            created_temporary = False
        finally:
            if created_temporary and os.path.lexists(temporary):
                os.unlink(temporary)
        return

    print(f"managed-links: create {target} -> {link_target}")
    if not dry_run:
        os.symlink(link_target, target)


def write_manifest(path: Path, desired: dict[str, Any]) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(path.parent, 0o700)
    state = {"version": 1, "links": desired["links"]}
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent, text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(state, stream, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def reconcile(desired: dict[str, Any], old: dict[str, Any], *, dry_run: bool) -> None:
    check_allowed_targets(desired)
    desired_targets = by_target(desired)
    old_targets = by_target(old)

    for target, entry in sorted(desired_targets.items()):
        install_link(
            target,
            entry["linkTarget"],
            old_targets.get(target),
            entry.get("adoptExistingSymlink", False),
            dry_run=dry_run,
        )

    for target, old_entry in sorted(old_targets.items()):
        if target not in desired_targets:
            remove_stale(target, old_entry["linkTarget"], dry_run=dry_run)


def main() -> int:
    parser = argparse.ArgumentParser(description="Reconcile declarative NixOS symlinks")
    parser.add_argument("--desired", required=True, type=Path)
    parser.add_argument("--state", required=True, type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    desired = load_manifest(args.desired, missing_ok=False)
    args.state.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    lock_path = args.state.with_suffix(f"{args.state.suffix}.lock")
    with lock_path.open("a+", encoding="utf-8") as lock:
        os.chmod(lock_path, 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        old = load_manifest(args.state, missing_ok=True)
        reconcile(desired, old, dry_run=args.dry_run)
        if not args.dry_run:
            write_manifest(args.state, desired)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ReconcileError as exc:
        print(f"managed-links: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
