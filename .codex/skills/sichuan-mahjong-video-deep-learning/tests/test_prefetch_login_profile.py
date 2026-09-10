#!/usr/bin/env python3

import importlib.util
import sqlite3
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts" / "prefetch_xiaolaoshi_video_library.py"
SPEC = importlib.util.spec_from_file_location("prefetch_xiaolaoshi_video_library", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class LoginProfileTests(unittest.TestCase):
    def create_cookie_db(self, root: Path, names: list[str]) -> None:
        database = root / "Default" / "Cookies"
        database.parent.mkdir(parents=True)
        connection = sqlite3.connect(database)
        try:
            connection.execute("CREATE TABLE cookies (host_key TEXT, name TEXT)")
            connection.executemany(
                "INSERT INTO cookies(host_key, name) VALUES('.douyin.com', ?)",
                [(name,) for name in names],
            )
            connection.commit()
        finally:
            connection.close()

    def test_missing_profile_requires_login(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            self.assertFalse(MODULE.profile_has_douyin_login(Path(temporary)))

    def test_anonymous_cookies_require_login(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.create_cookie_db(root, ["ttwid", "passport_csrf_token"])
            self.assertFalse(MODULE.profile_has_douyin_login(root))

    def test_authenticated_cookie_is_detected_without_reading_value(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.create_cookie_db(root, ["ttwid", "sessionid"])
            self.assertTrue(MODULE.profile_has_douyin_login(root))


if __name__ == "__main__":
    unittest.main()
