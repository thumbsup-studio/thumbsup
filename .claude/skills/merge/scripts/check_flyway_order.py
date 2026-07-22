#!/usr/bin/env python3
"""Reject unsafe Flyway history changes between two Git refs."""

from __future__ import annotations

import argparse
import collections
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import PurePosixPath


DEFAULT_MIGRATION_DIR = "server/src/main/resources/db/migration"
MIGRATION_NAME = re.compile(r"^V(?P<version>\d{14})__(?P<description>.+)\.sql$")
MAX_FUTURE_SKEW = timedelta(days=1)


class GitError(RuntimeError):
    pass


@dataclass(frozen=True)
class Migration:
    path: str
    version: str


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise GitError(f"git {' '.join(args)} failed: {detail}")
    return result


def resolve_commit(ref: str) -> str:
    return git("rev-parse", "--verify", f"{ref}^{{commit}}").stdout.strip()


def parse_migration(path: str, migration_dir: str) -> Migration | None:
    if not path.startswith(f"{migration_dir}/") or not path.endswith(".sql"):
        return None
    match = MIGRATION_NAME.match(PurePosixPath(path).name)
    if not match:
        raise ValueError(f"invalid migration filename: {path} (expected V<14 digits>__<name>.sql)")
    version = match.group("version")
    try:
        timestamp = datetime.strptime(version, "%Y%m%d%H%M%S")
    except ValueError as error:
        raise ValueError(f"invalid migration timestamp {version}: {path}") from error
    if timestamp > datetime.now() + MAX_FUTURE_SKEW:
        raise ValueError(f"migration timestamp is more than 24h in the future: {path}")
    return Migration(path=path, version=version)


def list_migrations(ref: str, migration_dir: str) -> tuple[list[Migration], list[str]]:
    output = git("ls-tree", "-r", "--name-only", ref, "--", migration_dir).stdout
    migrations: list[Migration] = []
    errors: list[str] = []
    for path in output.splitlines():
        try:
            migration = parse_migration(path, migration_dir)
        except ValueError as error:
            errors.append(str(error))
            continue
        if migration is not None:
            migrations.append(migration)
    return migrations, errors


def diff_entries(base: str, head: str, migration_dir: str) -> list[list[str]]:
    output = git(
        "diff",
        "--name-status",
        "--find-renames=50%",
        base,
        head,
        "--",
        migration_dir,
    ).stdout
    return [line.split("\t") for line in output.splitlines() if line]


def blob_oid(ref: str, path: str) -> str:
    return git("rev-parse", f"{ref}:{path}").stdout.strip()


def duplicate_version_errors(migrations: list[Migration], label: str) -> list[str]:
    by_version: dict[str, list[str]] = collections.defaultdict(list)
    for migration in migrations:
        by_version[migration.version].append(migration.path)
    return [
        f"{label} has duplicate Flyway version {version}: {', '.join(paths)}"
        for version, paths in sorted(by_version.items())
        if len(paths) > 1
    ]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check Flyway migration ordering and immutable-history rules between Git refs."
    )
    parser.add_argument("--base", default="origin/main", help="latest protected base ref")
    parser.add_argument("--head", default="HEAD", help="candidate PR head ref")
    parser.add_argument("--migration-dir", default=DEFAULT_MIGRATION_DIR)
    parser.add_argument(
        "--allow-renamed-version",
        action="append",
        default=[],
        metavar="VERSION",
        help="allow one exact base migration rename only after proving the version is absent in production history",
    )
    args = parser.parse_args()

    try:
        base_oid = resolve_commit(args.base)
        head_oid = resolve_commit(args.head)
        base_migrations, base_name_errors = list_migrations(base_oid, args.migration_dir)
        head_migrations, head_name_errors = list_migrations(head_oid, args.migration_dir)
        changes = diff_entries(base_oid, head_oid, args.migration_dir)
    except GitError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    errors = [*base_name_errors, *head_name_errors]
    warnings: list[str] = []
    errors.extend(duplicate_version_errors(base_migrations, args.base))
    errors.extend(duplicate_version_errors(head_migrations, args.head))

    ancestor = git("merge-base", "--is-ancestor", base_oid, head_oid, check=False)
    if ancestor.returncode != 0:
        errors.append(f"{args.head} is not based on latest {args.base}; rebase before checking")

    base_versions = {migration.version for migration in base_migrations}
    base_max = max(base_versions) if base_versions else None
    head_versions = {migration.version for migration in head_migrations}
    head_max = max(head_versions) if head_versions else None
    allowed_renames = set(args.allow_renamed_version)
    used_rename_overrides: set[str] = set()
    additions: list[Migration] = []
    rename_sources: dict[str, str] = {}

    for entry in changes:
        status = entry[0]
        kind = status[0]
        paths = entry[1:]

        if kind == "A" and len(paths) == 1:
            try:
                migration = parse_migration(paths[0], args.migration_dir)
            except ValueError as error:
                errors.append(str(error))
                continue
            if migration:
                additions.append(migration)
        elif kind == "M" and len(paths) == 1:
            errors.append(f"applied migration modified: {paths[0]}; restore it and add a forward migration")
        elif kind == "D" and len(paths) == 1:
            errors.append(f"applied migration deleted: {paths[0]}; restore it")
        elif kind == "R" and len(paths) == 2:
            old_path, new_path = paths
            try:
                old_migration = parse_migration(old_path, args.migration_dir)
                new_migration = parse_migration(new_path, args.migration_dir)
            except ValueError as error:
                errors.append(str(error))
                continue
            if old_migration is None or new_migration is None:
                errors.append(f"migration moved across directory boundary: {old_path} -> {new_path}")
                continue
            if old_migration.version not in allowed_renames:
                errors.append(
                    f"applied migration renamed: {old_path} -> {new_path}; "
                    "only allow after proving the old version is absent in production history"
                )
                continue
            used_rename_overrides.add(old_migration.version)
            additions.append(new_migration)
            rename_sources[new_migration.path] = old_migration.path
            warnings.append(
                f"override used for {old_migration.version}: {old_path} -> {new_path}; "
                "production history and partial-DDL evidence remain mandatory"
            )
        elif kind == "C" and len(paths) == 2:
            try:
                migration = parse_migration(paths[1], args.migration_dir)
            except ValueError as error:
                errors.append(str(error))
                continue
            if migration:
                additions.append(migration)
                warnings.append(f"migration copied from existing SQL: {paths[0]} -> {paths[1]}")
        else:
            errors.append(f"unsupported migration history change: {' '.join(entry)}")

    unused_overrides = allowed_renames - used_rename_overrides
    for version in sorted(unused_overrides):
        errors.append(f"rename override {version} did not match an actual renamed base migration")

    for migration in additions:
        if migration.version in base_versions:
            errors.append(f"new migration reuses base version {migration.version}: {migration.path}")
        if base_max is not None and migration.version <= base_max:
            errors.append(
                f"new migration {migration.version} is not above base max {base_max}: {migration.path}"
            )

    base_paths_by_blob: dict[str, list[str]] = collections.defaultdict(list)
    for migration in base_migrations:
        try:
            base_paths_by_blob[blob_oid(base_oid, migration.path)].append(migration.path)
        except GitError as error:
            errors.append(str(error))

    additions_by_blob: dict[str, list[str]] = collections.defaultdict(list)
    for migration in additions:
        try:
            content_blob = blob_oid(head_oid, migration.path)
        except GitError as error:
            errors.append(str(error))
            continue
        additions_by_blob[content_blob].append(migration.path)
        duplicated_base_paths = [
            path
            for path in base_paths_by_blob.get(content_blob, [])
            if path != rename_sources.get(migration.path)
        ]
        if duplicated_base_paths:
            errors.append(
                f"new migration duplicates SQL already in base: {migration.path} == "
                f"{', '.join(duplicated_base_paths)}"
            )

    for paths in additions_by_blob.values():
        if len(paths) > 1:
            errors.append(f"candidate migrations contain identical SQL: {', '.join(sorted(paths))}")

    for new_path, old_path in rename_sources.items():
        old_version = parse_migration(old_path, args.migration_dir).version
        stale_references = git(
            "grep",
            "-n",
            "-F",
            old_version,
            head_oid,
            "--",
            "server/src",
            check=False,
        )
        if stale_references.returncode == 0:
            matches = stale_references.stdout.strip().splitlines()
            preview = "; ".join(matches[:5])
            errors.append(
                f"renamed version {old_version} still appears under server/src after {old_path} -> {new_path}: "
                f"{preview}"
            )
        elif stale_references.returncode not in (0, 1):
            detail = stale_references.stderr.strip() or stale_references.stdout.strip()
            errors.append(f"git grep for renamed version {old_version} failed: {detail}")

    print(f"base: {args.base} ({base_oid}) max={base_max or 'none'} migrations={len(base_migrations)}")
    print(f"head: {args.head} ({head_oid}) max={head_max or 'none'} migrations={len(head_migrations)}")
    if additions:
        print("candidate additions:")
        for migration in sorted(additions, key=lambda item: (item.version, item.path)):
            print(f"  - {migration.version} {migration.path}")
    else:
        print("candidate additions: none")
    for warning in warnings:
        print(f"WARNING: {warning}")
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)

    if errors:
        print("RESULT: BLOCKED", file=sys.stderr)
        return 1

    print("RESULT: STATIC PASS ONLY (not merge approval; verify production history, open PRs, SQL risk, and MySQL upgrade)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
