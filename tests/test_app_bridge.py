from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from amnesia.app_bridge import dispatch

from .fake_home import FakeHome, ThreadSpec


class AppBridgeTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name) / "codex"
        FakeHome(
            self.root,
            threads=[ThreadSpec("old-1", age_days=40, size_bytes=4096)],
        ).build()

    def test_state_is_read_only_and_machine_readable(self) -> None:
        before = {
            path.relative_to(self.root): path.read_bytes()
            for path in self.root.rglob("*")
            if path.is_file()
        }
        patches = [
            mock.patch("amnesia.application.codex_processes", return_value=[]),
            mock.patch("amnesia.engine.codex_processes", return_value=[]),
            mock.patch("amnesia.tasks.environment.codex_processes", return_value=[]),
        ]
        for patcher in patches:
            patcher.start()
            self.addCleanup(patcher.stop)

        result = dispatch("state", {"home": str(self.root)})

        self.assertTrue(result["ok"])
        self.assertEqual(result["home"], str(self.root.resolve()))
        self.assertIn("assessment", result)
        self.assertIn("items", result)
        self.assertEqual(result["capacity_gauge_bytes"], 10 * 1024**3)
        self.assertGreaterEqual(result["active_footprint_bytes"], 4096)
        after = {
            path.relative_to(self.root): path.read_bytes()
            for path in self.root.rglob("*")
            if path.is_file()
        }
        self.assertEqual(before, after)

    def test_unknown_command_is_rejected(self) -> None:
        result = dispatch("unknown", {"home": str(self.root)})
        self.assertFalse(result["ok"])
        self.assertTrue(result["blocked"])


class BrandingTest(unittest.TestCase):
    def test_bundle_identity_and_retired_name(self) -> None:
        root = Path(__file__).resolve().parents[1]
        plist = (root / "macos" / "Resources" / "Info.plist").read_text(encoding="utf-8")
        self.assertIn("medusia.com.amnesia", plist)
        self.assertIn("<string>Amnesia</string>", plist)

        forbidden = (
            ("codex" + "_tidy").encode(),
            ("codex" + "-tidy").encode(),
            ("Codex" + " Tidy").encode(),
        )
        for path in root.rglob("*"):
            if not path.is_file() or ".git" in path.parts or "__pycache__" in path.parts:
                continue
            if path.suffix in {".pyc", ".zip"}:
                continue
            data = path.read_bytes()
            for needle in forbidden:
                self.assertNotIn(needle, data, str(path))


if __name__ == "__main__":
    unittest.main()
