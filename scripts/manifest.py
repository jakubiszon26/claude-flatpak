"""Render the build manifest using a record from the authenticated APT index."""
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
    raise SystemExit("Unexpected APT record")
filename = record["Filename"] or ""
if not re.fullmatch(r"pool/(?:[\w.+~-]+/)*claude-desktop_[\w.+~-]+_amd64\.deb", filename):
    raise SystemExit("Unexpected APT filename")
checksum = record["SHA256"] or ""
size = int(record["Size"])
if not re.fullmatch("[0-9a-f]{64}", checksum) or size <= 0:
    raise SystemExit("Invalid package checksum or size")
manifest = yaml.safe_load(Path("com.anthropic.Claude.yaml").read_text())
manifest["modules"][0]["sources"].append({
    "type": "extra-data", "filename": "claude.deb",
    "url": "https://downloads.claude.ai/claude-desktop/apt/stable/" + filename,
    "sha256": checksum, "size": size,
})
Path("build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
