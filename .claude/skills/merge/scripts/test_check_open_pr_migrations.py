#!/usr/bin/env python3
"""Unit tests for open-PR Flyway collision decisions."""

from __future__ import annotations

import unittest

from check_flyway_order import Migration
from check_open_pr_migrations import OpenMigration, evaluate_collisions, validate_current_pull


def candidate(version: str, name: str = "candidate") -> Migration:
    return Migration(
        path=f"server/src/main/resources/db/migration/V{version}__{name}.sql",
        version=version,
    )


def opened(pr: int, version: str, blob: str = "open-blob") -> OpenMigration:
    return OpenMigration(
        pr_number=pr,
        head_oid=f"head-{pr}",
        path=f"server/src/main/resources/db/migration/V{version}__open.sql",
        version=version,
        blob_oid=blob,
    )


class OpenPrCollisionTest(unittest.TestCase):
    def test_current_pr_must_match_recorded_base_and_head(self) -> None:
        pull = {
            "number": 7,
            "state": "open",
            "base": {"ref": "main", "sha": "actual-base"},
            "head": {"sha": "actual-head"},
        }
        errors = validate_current_pull(pull, 7, "expected-base", "expected-head")
        self.assertTrue(any("base OID mismatch" in error for error in errors))
        self.assertTrue(any("head OID mismatch" in error for error in errors))

    def test_current_pr_identity_accepts_exact_snapshot(self) -> None:
        pull = {
            "number": 7,
            "state": "open",
            "base": {"ref": "main", "sha": "base"},
            "head": {"sha": "head"},
        }
        self.assertEqual([], validate_current_pull(pull, 7, "base", "head"))

    def test_blocks_same_version(self) -> None:
        current = candidate("20200101130000")
        errors, _ = evaluate_collisions([current], {current.path: "candidate-blob"}, {2: [opened(2, current.version)]})
        self.assertTrue(any("collides with open PR #2" in error for error in errors))

    def test_blocks_identical_sql(self) -> None:
        current = candidate("20200101130000")
        errors, _ = evaluate_collisions([current], {current.path: "same"}, {2: [opened(2, "20200101140000", "same")]})
        self.assertTrue(any("duplicates open PR #2" in error for error in errors))

    def test_blocks_when_open_pr_has_lower_range(self) -> None:
        current = candidate("20200101150000")
        errors, _ = evaluate_collisions([current], {current.path: "candidate"}, {2: [opened(2, "20200101140000")]})
        self.assertTrue(any("merge it first or renumber" in error for error in errors))

    def test_allows_current_lower_range_with_handoff_warning(self) -> None:
        current = candidate("20200101130000")
        errors, warnings = evaluate_collisions(
            [current], {current.path: "candidate"}, {2: [opened(2, "20200101140000")]}
        )
        self.assertEqual([], errors)
        self.assertTrue(any("candidate must merge before" in warning for warning in warnings))

    def test_blocks_interleaving_ranges(self) -> None:
        first = candidate("20200101130000", "first")
        second = candidate("20200101150000", "second")
        errors, _ = evaluate_collisions(
            [first, second],
            {first.path: "first", second.path: "second"},
            {2: [opened(2, "20200101140000")]},
        )
        self.assertTrue(any("interleaves open PR #2" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
