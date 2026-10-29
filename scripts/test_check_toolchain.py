import unittest

from check_toolchain import supported


class ToolchainRequirementTests(unittest.TestCase):
    def test_rejects_old_and_unrecognized_versions(self):
        for version in ["v0.10.9", "v0.10.12+1634b282e", "v0.10.13", "v0.9.999", "unknown", "Python 3.14.0", "v0.10.14.1"]:
            with self.subTest(version=version):
                self.assertFalse(supported(version))

    def test_accepts_minimum_and_newer_stable_versions(self):
        for version in ["v0.10.14", "moonc v0.10.14+7d59c7ec9 (2026-09-21)", "v0.10.15", "v0.11.0", "v1.0.0"]:
            with self.subTest(version=version):
                self.assertTrue(supported(version))

    def test_rejects_prerelease_as_acceptance_baseline(self):
        self.assertFalse(supported("v0.10.14-rc1"))


if __name__ == "__main__":
    unittest.main()
