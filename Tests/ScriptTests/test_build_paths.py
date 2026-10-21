"""Check script behavior without requiring AppKit or changing user directories."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"


class BuildPathTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.checkout = self.root / "Dropbox checkout with spaces"
        (self.checkout / "scripts").mkdir(parents=True)
        for filename in ["build-paths.sh", "test.sh"]:
            shutil.copyfile(SCRIPTS / filename, self.checkout / "scripts" / filename)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        uname = self.bin / "uname"
        uname.write_text("#!/bin/sh\nprintf 'Darwin\\n'\n")
        uname.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.env.pop("TRACKBOARD_BUILD_DIR", None)

    def paths(self, checkout=None):
        checkout = checkout or self.checkout
        output = subprocess.check_output([
            "bash", "-c",
            'source "$1"; printf "%s\\0%s\\0%s" "$TRACKBOARD_ROOT" '
            '"$TRACKBOARD_SCRATCH_PATH" "$TRACKBOARD_APP_PATH"',
            "test-paths", str(checkout / "scripts/build-paths.sh"),
        ], env=self.env)
        return [Path(value.decode()) for value in output.split(b"\0")]

    def test_macos_outputs_are_outside_cloud_checkout(self):
        root, scratch, app = self.paths()
        self.assertEqual(root, self.checkout.resolve())
        expected_cache = Path(os.environ["HOME"]) / "Library/Caches/Trackboard"
        self.assertTrue(scratch.is_relative_to(expected_cache))
        self.assertTrue(app.is_relative_to(expected_cache))
        self.assertFalse(scratch.is_relative_to(root))
        self.assertFalse(app.is_relative_to(root))

    def test_each_checkout_has_its_own_cache(self):
        other = self.root / "second checkout"
        (other / "scripts").mkdir(parents=True)
        shutil.copyfile(SCRIPTS / "build-paths.sh", other / "scripts/build-paths.sh")
        self.assertNotEqual(self.paths()[1], self.paths(other)[1])

    def test_override_with_spaces_is_preserved_without_creating_it(self):
        build = self.root / "unsynced build folder"
        self.env["TRACKBOARD_BUILD_DIR"] = str(build)
        _, scratch, app = self.paths()
        self.assertEqual(scratch, build / "swiftpm")
        self.assertEqual(app, build / "Trackboard.app")
        self.assertFalse(build.exists())

    def test_relative_override_is_resolved_against_checkout(self):
        self.env["TRACKBOARD_BUILD_DIR"] = "custom output"
        _, scratch, _ = self.paths()
        self.assertEqual(scratch, self.checkout.resolve() / "custom output/swiftpm")

    def test_checkout_symlink_uses_the_same_cache_as_its_target(self):
        alias = self.root / "checkout alias"
        alias.symlink_to(self.checkout, target_is_directory=True)
        self.assertEqual(self.paths(alias), self.paths())

    def test_test_wrapper_forwards_scratch_path_and_arguments(self):
        swift = self.bin / "swift"
        swift.write_text("#!/usr/bin/env python3\nimport json, sys\nprint(json.dumps(sys.argv[1:]))\n")
        swift.chmod(0o755)
        build = self.root / "build directory with spaces"
        self.env["TRACKBOARD_BUILD_DIR"] = str(build)
        output = subprocess.check_output([
            "bash", str(self.checkout / "scripts/test.sh"), "--filter", "InkTests"
        ], env=self.env, text=True)
        self.assertEqual(json.loads(output), [
            "test", "--scratch-path", str(build / "swiftpm"), "--filter", "InkTests"
        ])


if __name__ == "__main__":
    unittest.main()
