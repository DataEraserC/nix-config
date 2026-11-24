from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = Path(
    os.environ.get(
        "MANAGED_LINKS_SCRIPT",
        ROOT / "modules/nixos/base/custom/system/managed-links/managed_links.py",
    )
)


class ManagedLinksTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.targets = self.root / "targets"
        self.sources = self.root / "sources"
        self.state = self.root / "state" / "manifest.json"
        self.targets.mkdir()
        self.sources.mkdir()
        self.source_a = self.sources / "a"
        self.source_b = self.sources / "b"
        self.source_a.write_text("a", encoding="utf-8")
        self.source_b.write_text("b", encoding="utf-8")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def desired(
        self,
        links: dict[str, tuple[Path, Path]],
        adopt_existing: set[str] | None = None,
    ) -> Path:
        adopt_existing = adopt_existing or set()
        path = self.root / "desired.json"
        path.write_text(
            json.dumps(
                {
                    "version": 1,
                    "allowedTargetPrefixes": [str(self.targets)],
                    "links": {
                        name: {
                            "target": str(target),
                            "linkTarget": str(source),
                            "adoptExistingSymlink": name in adopt_existing,
                        }
                        for name, (target, source) in links.items()
                    },
                }
            ),
            encoding="utf-8",
        )
        return path

    def apply(
        self,
        links: dict[str, tuple[Path, Path]],
        *,
        adopt_existing: set[str] | None = None,
        succeeds: bool = True,
    ) -> None:
        result = subprocess.run(
            [
                "python3",
                str(SCRIPT),
                "--desired",
                str(self.desired(links, adopt_existing)),
                "--state",
                str(self.state),
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        if succeeds and result.returncode != 0:
            self.fail(result.stderr)
        if not succeeds and result.returncode == 0:
            self.fail("reconciliation unexpectedly succeeded")

    def test_create_and_repeat_without_replacing_link(self) -> None:
        target = self.targets / "link"
        links = {"example": (target, self.source_a)}
        self.apply(links)
        inode = target.lstat().st_ino
        self.apply(links)
        self.assertEqual(target.lstat().st_ino, inode)
        self.assertEqual(os.readlink(target), str(self.source_a))

    def test_update_and_rollback(self) -> None:
        target = self.targets / "link"
        self.apply({"example": (target, self.source_a)})
        self.apply({"example": (target, self.source_b)})
        self.assertEqual(os.readlink(target), str(self.source_b))
        self.apply({"example": (target, self.source_a)})
        self.assertEqual(os.readlink(target), str(self.source_a))

    def test_removed_owned_link_is_cleaned(self) -> None:
        target = self.targets / "link"
        self.apply({"example": (target, self.source_a)})
        self.apply({})
        self.assertFalse(os.path.lexists(target))

    def test_modified_stale_link_is_left_for_user(self) -> None:
        target = self.targets / "link"
        self.apply({"example": (target, self.source_a)})
        target.unlink()
        target.symlink_to(self.source_b)
        self.apply({})
        self.assertEqual(os.readlink(target), str(self.source_b))
        state = json.loads(self.state.read_text(encoding="utf-8"))
        self.assertEqual(state["links"], {})

    def test_declared_existing_symlink_is_adopted(self) -> None:
        target = self.targets / "link"
        target.symlink_to(self.source_b)
        self.apply(
            {"example": (target, self.source_a)},
            adopt_existing={"example"},
        )
        self.assertEqual(os.readlink(target), str(self.source_a))

    def test_parent_symlink_is_rejected(self) -> None:
        real_parent = self.root / "real-targets"
        real_parent.mkdir()
        self.targets.rmdir()
        self.targets.symlink_to(real_parent, target_is_directory=True)
        target = self.targets / "link"
        self.apply({"example": (target, self.source_a)}, succeeds=False)
        self.assertFalse(os.path.lexists(real_parent / "link"))

    def test_collision_does_not_remove_stale_links_first(self) -> None:
        old_target = self.targets / "old"
        self.apply({"old": (old_target, self.source_a)})
        collision = self.targets / "collision"
        collision.write_text("user data", encoding="utf-8")
        self.apply({"new": (collision, self.source_b)}, succeeds=False)
        self.assertTrue(old_target.is_symlink())
        self.assertEqual(os.readlink(old_target), str(self.source_a))

    def test_regular_file_collision_is_never_replaced(self) -> None:
        target = self.targets / "link"
        target.write_text("user data", encoding="utf-8")
        self.apply({"example": (target, self.source_a)}, succeeds=False)
        self.assertEqual(target.read_text(encoding="utf-8"), "user data")
        self.assertFalse(self.state.exists())

    def test_unmanaged_symlink_collision_is_never_replaced(self) -> None:
        target = self.targets / "link"
        target.symlink_to(self.source_b)
        self.apply({"example": (target, self.source_a)}, succeeds=False)
        self.assertEqual(os.readlink(target), str(self.source_b))

    def test_target_outside_allowlist_is_rejected(self) -> None:
        target = self.root / "outside"
        self.apply({"example": (target, self.source_a)}, succeeds=False)
        self.assertFalse(os.path.lexists(target))


if __name__ == "__main__":
    unittest.main()
