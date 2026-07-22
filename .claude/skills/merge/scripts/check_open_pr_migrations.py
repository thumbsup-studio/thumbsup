#!/usr/bin/env python3
"""Compare candidate Flyway migrations with stable snapshots of all open PRs."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass

from check_flyway_order import GitError, Migration, blob_oid, list_migrations, parse_migration, resolve_commit


@dataclass(frozen=True)
class OpenMigration:
    pr_number: int
    head_oid: str
    path: str
    version: str
    blob_oid: str


def gh(*args: str) -> str:
    result = subprocess.run(
        ["gh", *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"gh {' '.join(args)} failed: {detail}")
    return result.stdout


def api_json(path: str) -> object:
    return json.loads(gh("api", "--method", "GET", path))


def paginated(path: str) -> list[dict[str, object]]:
    items: list[dict[str, object]] = []
    page = 1
    separator = "&" if "?" in path else "?"
    while True:
        batch = api_json(f"{path}{separator}per_page=100&page={page}")
        if not isinstance(batch, list):
            raise RuntimeError(f"expected list response from {path}")
        items.extend(batch)
        if len(batch) < 100:
            return items
        page += 1


def parse_version(path: str, migration_dir: str) -> str | None:
    try:
        migration = parse_migration(path, migration_dir)
    except ValueError as error:
        raise RuntimeError(str(error)) from error
    return migration.version if migration is not None else None


def pull_snapshot(repo: str, number: int, migration_dir: str) -> tuple[str, list[OpenMigration], list[str]]:
    before = api_json(f"repos/{repo}/pulls/{number}")
    if not isinstance(before, dict):
        raise RuntimeError(f"invalid pull response for #{number}")
    before_head = str(before["head"]["sha"])
    before_base = str(before["base"]["sha"])
    files = paginated(f"repos/{repo}/pulls/{number}/files")
    after = api_json(f"repos/{repo}/pulls/{number}")
    if not isinstance(after, dict):
        raise RuntimeError(f"invalid second pull response for #{number}")
    after_head = str(after["head"]["sha"])
    after_base = str(after["base"]["sha"])
    if before_head != after_head:
        raise RuntimeError(f"open PR #{number} moved during file scan: {before_head} -> {after_head}")
    if before_base != after_base:
        raise RuntimeError(f"open PR #{number} base moved during file scan: {before_base} -> {after_base}")
    if after.get("state") != "open" or after["base"]["ref"] != "main":
        raise RuntimeError(f"open PR #{number} changed state or base during file scan")

    migrations: list[OpenMigration] = []
    warnings: list[str] = []
    for item in files:
        path = str(item.get("filename", ""))
        previous = str(item.get("previous_filename", ""))
        status = str(item.get("status", ""))
        version = parse_version(path, migration_dir)
        previous_version = parse_version(previous, migration_dir) if previous else None
        if version is None and previous_version is None:
            continue
        if status not in {"added", "renamed"}:
            warnings.append(f"open PR #{number}@{before_head} {status} existing migration: {path or previous}")
            continue
        if version is None:
            warnings.append(f"open PR #{number}@{before_head} moves migration out of directory: {previous} -> {path}")
            continue
        if status == "renamed":
            warnings.append(f"open PR #{number}@{before_head} renames migration: {previous} -> {path}")
        migrations.append(
            OpenMigration(
                pr_number=number,
                head_oid=before_head,
                path=path,
                version=version,
                blob_oid=str(item.get("sha", "")),
            )
        )
    return before_head, migrations, warnings


def validate_current_pull(pull: object, number: int, base_oid: str, head_oid: str) -> list[str]:
    if not isinstance(pull, dict):
        return [f"invalid current PR response for #{number}"]
    errors: list[str] = []
    if int(pull.get("number", -1)) != number:
        errors.append(f"current PR number mismatch: expected #{number}")
    if pull.get("state") != "open":
        errors.append(f"current PR #{number} is not open")
    try:
        actual_base_ref = str(pull["base"]["ref"])
        actual_base_oid = str(pull["base"]["sha"])
        actual_head_oid = str(pull["head"]["sha"])
    except (KeyError, TypeError) as error:
        return [*errors, f"current PR #{number} is missing base/head identity: {error}"]
    if actual_base_ref != "main":
        errors.append(f"current PR #{number} base is {actual_base_ref}, not main")
    if actual_base_oid != base_oid:
        errors.append(f"current PR #{number} base OID mismatch: expected {base_oid}, got {actual_base_oid}")
    if actual_head_oid != head_oid:
        errors.append(f"current PR #{number} head OID mismatch: expected {head_oid}, got {actual_head_oid}")
    return errors


def pull_identity(pull: object) -> tuple[object, object]:
    if not isinstance(pull, dict):
        return None, None
    base = pull.get("base")
    head = pull.get("head")
    if not isinstance(base, dict) or not isinstance(head, dict):
        return None, None
    return base.get("sha"), head.get("sha")


def evaluate_collisions(
    candidates: list[Migration],
    candidate_blobs: dict[str, str],
    open_by_pr: dict[int, list[OpenMigration]],
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    candidate_versions = {migration.version: migration.path for migration in candidates}
    candidate_min = min(candidate_versions) if candidate_versions else None
    candidate_max = max(candidate_versions) if candidate_versions else None

    for number, migrations in sorted(open_by_pr.items()):
        open_versions = {migration.version for migration in migrations}
        for migration in migrations:
            if migration.version in candidate_versions:
                errors.append(
                    f"candidate version {migration.version} collides with open PR #{number}: "
                    f"{candidate_versions[migration.version]} vs {migration.path}"
                )
            for candidate_path, candidate_blob in candidate_blobs.items():
                if candidate_blob and candidate_blob == migration.blob_oid:
                    errors.append(
                        f"candidate SQL duplicates open PR #{number}: {candidate_path} == {migration.path}"
                    )
        open_min = min(open_versions)
        open_max = max(open_versions)
        if candidate_min is None or candidate_max is None:
            continue
        if open_max < candidate_min:
            errors.append(
                f"open PR #{number} has lower migration range {open_min}..{open_max}; "
                "merge it first or renumber before this candidate"
            )
        elif candidate_max < open_min:
            warnings.append(
                f"candidate must merge before open PR #{number} ({candidate_min}..{candidate_max} < {open_min}..{open_max}); "
                "handoff a latest-main rebase"
            )
        else:
            errors.append(
                f"candidate range {candidate_min}..{candidate_max} interleaves open PR #{number} "
                f"range {open_min}..{open_max}"
            )
    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description="Check candidate Flyway migrations against open PR snapshots.")
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--current-pr", type=int, required=True)
    parser.add_argument("--repo", help="OWNER/REPO; defaults to gh repo view")
    parser.add_argument("--migration-dir", default="server/src/main/resources/db/migration")
    args = parser.parse_args()
    errors: list[str] = []
    warnings: list[str] = []

    try:
        base_oid = resolve_commit(args.base)
        head_oid = resolve_commit(args.head)
        base_migrations, base_errors = list_migrations(base_oid, args.migration_dir)
        head_migrations, head_errors = list_migrations(head_oid, args.migration_dir)
        if base_errors or head_errors:
            raise RuntimeError("; ".join([*base_errors, *head_errors]))
        repo = args.repo or gh("repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner").strip()
        current_before = api_json(f"repos/{repo}/pulls/{args.current_pr}")
        pulls = paginated(f"repos/{repo}/pulls?state=open&base=main")
    except (GitError, RuntimeError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    base_paths = {migration.path for migration in base_migrations}
    candidates = [migration for migration in head_migrations if migration.path not in base_paths]
    candidate_blobs: dict[str, str] = {}
    errors.extend(validate_current_pull(current_before, args.current_pr, base_oid, head_oid))
    if not any(int(pull["number"]) == args.current_pr for pull in pulls):
        errors.append(f"current PR #{args.current_pr} is not in the open main PR snapshot")
    try:
        for migration in candidates:
            candidate_blobs[migration.path] = blob_oid(head_oid, migration.path)
    except GitError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    open_by_pr: dict[int, list[OpenMigration]] = {}
    for pull in pulls:
        number = int(pull["number"])
        if number == args.current_pr:
            continue
        try:
            _, migrations, snapshot_warnings = pull_snapshot(repo, number, args.migration_dir)
        except (RuntimeError, json.JSONDecodeError, KeyError, TypeError) as error:
            errors.append(str(error))
            continue
        if migrations:
            open_by_pr[number] = migrations
        warnings.extend(snapshot_warnings)

    try:
        current_after = api_json(f"repos/{repo}/pulls/{args.current_pr}")
    except (RuntimeError, json.JSONDecodeError) as error:
        errors.append(str(error))
    else:
        errors.extend(validate_current_pull(current_after, args.current_pr, base_oid, head_oid))
        if pull_identity(current_before) != pull_identity(current_after):
            errors.append(f"current PR #{args.current_pr} moved during open-PR scan")

    collision_errors, collision_warnings = evaluate_collisions(candidates, candidate_blobs, open_by_pr)
    errors.extend(collision_errors)
    warnings.extend(collision_warnings)
    errors = list(dict.fromkeys(errors))
    warnings = list(dict.fromkeys(warnings))

    print(f"repo: {repo}")
    print(f"candidate: {args.head} ({head_oid}) migrations={len(candidates)}")
    print(f"open PRs scanned: {len(pulls) - sum(1 for pull in pulls if int(pull['number']) == args.current_pr)}")
    for warning in warnings:
        print(f"WARNING: {warning}")
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    if errors:
        print("RESULT: BLOCKED", file=sys.stderr)
        return 1
    print("RESULT: OPEN-PR SNAPSHOT PASS ONLY (rerun immediately before merge)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
