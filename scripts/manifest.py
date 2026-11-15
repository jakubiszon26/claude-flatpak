"""Render build-manifest.json from the packaging manifest.

Usage: manifest.py APT_RECORD_FILE VERSION

Adds an extra-data source that points at Anthropic's own download server, using
the file name, checksum, and size from the authenticated APT index. Flatpak
then fetches and verifies the package on the user's machine at install time.
"""
import json
import re
import sys
from email.parser import Parser
from pathlib import Path

import yaml

record = Parser().parsestr(Path(sys.argv[1]).read_text().split("\n\n")[0])
if (record["Package"], record["Architecture"], record["Version"]) != (
    "claude-desktop", "amd64", sys.argv[2]
):
    raise SystemExit(
        "The APT record is not claude-desktop/amd64 at the expected version: "
        f"{record['Package']} {record['Architecture']} {record['Version']}"
    )
filename = record["Filename"] or ""
if not re.fullmatch(r"pool/(?:[\w.+~-]+/)*claude-desktop_[\w.+~-]+_amd64\.deb", filename):
    raise SystemExit(f"Unexpected package path in the APT index: {filename!r}")
checksum = record["SHA256"] or ""
size = int(record["Size"] or 0)
if not re.fullmatch("[0-9a-f]{64}", checksum) or size <= 0:
    raise SystemExit("The APT index has no valid SHA-256 checksum or size for the package")
manifest = yaml.safe_load(Path("com.anthropic.Claude.yaml").read_text())
manifest["modules"][0]["sources"].append({
    "type": "extra-data", "filename": "claude.deb",
    "url": "https://downloads.claude.ai/claude-desktop/apt/stable/" + filename,
    "sha256": checksum, "size": size,
})
Path("build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
