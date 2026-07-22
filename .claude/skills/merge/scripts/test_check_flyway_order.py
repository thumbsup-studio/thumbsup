#!/usr/bin/env python3
"""Regression tests for the Flyway history checker."""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path


CHECKER = Path(__file__).with_name("check_flyway_order.py")
MIGRATION_DIR = Path("server/src/main/resources/db/migration")


class RepoFixture:
    def __init__(self, migrations: dict[str, str]) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Merge Skill Test")
        self.git("config", "user.email", "merge-skill@example.invalid")
        for name, content in migrations.items():
            self.write(name, content)
        self.base = self.commit("base")

    def close(self) -> None:
        self.temp.cleanup()

    def git(self, *args: str) -> str:
        result = subprocess.run(
            ["git", *args],
            cwd=self.root,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return result.stdout.strip()

    def write(self, name: str, content: str) -> None:
        path = self.root / MIGRATION_DIR / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def remove(self, name: str) -> None:
        (self.root / MIGRATION_DIR / name).unlink()

    def commit(self, message: str) -> str:
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)
        return self.git("rev-parse", "HEAD")

    def check(self, *extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(CHECKER), "--base", self.base, "--head", "HEAD", *extra],
            cwd=self.root,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )


class FlywayOrderCheckerTest(unittest.TestCase):
    def make_repo(self, migrations: dict[str, str]) -> RepoFixture:
        fixture = RepoFixture(migrations)
        self.addCleanup(fixture.close)
        return fixture

    def test_blocks_new_version_below_base_max(self) -> None:
        repo = self.make_repo({"V20200101130000__base.sql": "SELECT 13;\n"})
        repo.write("V20200101120000__late.sql", "SELECT 12;\n")
        repo.commit("late")

        result = repo.check()

        self.assertEqual(1, result.returncode)
        self.assertIn("not above base max", result.stdout)

    def test_blocks_modified_existing_migration(self) -> None:
        repo = self.make_repo({"V20200101130000__base.sql": "SELECT 1;\n"})
        repo.write("V20200101130000__base.sql", "SELECT 2;\n")
        repo.commit("modify")

        result = repo.check()

        self.assertEqual(1, result.returncode)
        self.assertIn("applied migration modified", result.stdout)

    def test_blocks_duplicate_sql_under_new_version(self) -> None:
        repo = self.make_repo({"V20200101130000__base.sql": "SELECT 1;\n"})
        repo.write("V20200101150000__duplicate.sql", "SELECT 1;\n")
        repo.commit("duplicate")

        result = repo.check()

        self.assertEqual(1, result.returncode)
        self.assertIn("duplicates SQL already in base", result.stdout)

    def test_requires_explicit_proof_for_rename(self) -> None:
        old_name = "V20200101120000__old.sql"
        repo = self.make_repo(
            {
                old_name: """-- retry-safe helper table
CREATE TABLE migration_20200101120000_marker
(
    id BIGINT NOT NULL,
    marker_order INT NOT NULL,
    content TEXT NOT NULL,
    PRIMARY KEY (id, marker_order)
);
TRUNCATE TABLE migration_20200101120000_marker;
DROP TABLE migration_20200101120000_marker;
""",
                "V20200101130000__base.sql": "SELECT 13;\n",
            }
        )
        old_content = (repo.root / MIGRATION_DIR / old_name).read_text(encoding="utf-8")
        repo.remove(old_name)
        repo.write(
            "V20200101150000__old.sql",
            old_content.replace("20200101120000", "20200101150000"),
        )
        repo.commit("rename")

        blocked = repo.check()
        allowed = repo.check("--allow-renamed-version", "20200101120000")

        self.assertEqual(1, blocked.returncode)
        self.assertIn("applied migration renamed", blocked.stdout)
        self.assertEqual(0, allowed.returncode)
        self.assertIn("STATIC PASS ONLY", allowed.stdout)

    def test_rejects_invalid_calendar_timestamp(self) -> None:
        repo = self.make_repo({"V20200101130000__base.sql": "SELECT 13;\n"})
        repo.write("V20201301150000__invalid.sql", "SELECT 15;\n")
        repo.commit("invalid")

        result = repo.check()

        self.assertEqual(1, result.returncode)
        self.assertIn("invalid migration timestamp", result.stdout)

    def test_rejects_timestamp_more_than_one_day_in_future(self) -> None:
        repo = self.make_repo({"V20200101130000__base.sql": "SELECT 13;\n"})
        future = (datetime.now() + timedelta(days=2)).strftime("%Y%m%d%H%M%S")
        repo.write(f"V{future}__future.sql", "SELECT 99;\n")
        repo.commit("future")

        result = repo.check()

        self.assertEqual(1, result.returncode)
        self.assertIn("more than 24h in the future", result.stdout)

    def test_allows_forward_unique_migration(self) -> None:
        repo = self.make_repo({"V20200101130000__base.sql": "SELECT 13;\n"})
        repo.write("V20200101150000__forward.sql", "SELECT 15;\n")
        repo.commit("forward")

        result = repo.check()

        self.assertEqual(0, result.returncode)
        self.assertIn("STATIC PASS ONLY", result.stdout)


if __name__ == "__main__":
    unittest.main()
