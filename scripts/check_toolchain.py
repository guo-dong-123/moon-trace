#!/usr/bin/env python3
"""Enforce the minimum compiler version required for project acceptance."""
import argparse
import re
import subprocess
import sys

MINIMUM = (0, 10, 14)


def supported(output):
    match = re.match(r"(?:moonc\s+)?v?(\d+)\.(\d+)\.(\d+)([^\s]*)", output.strip())
    if not match:
        return False
    version = tuple(int(part) for part in match.group(1, 2, 3))
    # Build hashes are allowed; prerelease compilers are not the acceptance baseline.
    suffix = match.group(4)
    return version >= MINIMUM and (not suffix or suffix.startswith("+"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--moonc", default="moonc", help="compiler executable")
    args = parser.parse_args()
    try:
        result = subprocess.run([args.moonc, "-v"], text=True, capture_output=True,
                                check=True, timeout=15)
    except (OSError, subprocess.SubprocessError) as error:
        print(f"FAIL: cannot check MoonBit compiler: {error}", file=sys.stderr)
        return 1
    output = (result.stdout + result.stderr).strip()
    if not supported(output):
        print(f"FAIL: moonc >= 0.10.14 is required; found: {output}", file=sys.stderr)
        return 1
    print(f"PASS: {output} satisfies moonc >= 0.10.14")
    return 0


if __name__ == "__main__":
    sys.exit(main())
