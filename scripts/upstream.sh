#!/usr/bin/env bash
# Reads the current Claude Desktop version, checksum, and size from Anthropic's
# signed APT index and renders build-manifest.json. The package itself is not
# downloaded here. Runs on the disposable Ubuntu Actions runner.
set -euo pipefail

die() {
  echo "::error::$*" >&2
  exit 1
}

base=https://downloads.claude.ai/claude-desktop
# Anthropic's package signing key, as documented at
# https://code.claude.com/docs/en/desktop-linux
fingerprint=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE

key=$(mktemp)
trap 'rm -f "$key"' EXIT
curl --fail --silent --show-error --location "$base/key.asc" -o "$key" ||
  die "Could not download Anthropic's signing key from $base/key.asc"
primary_keys=$(gpg --batch --with-colons --show-keys "$key" |
  awk -F: '$1=="pub"{primary=1} $1=="fpr" && primary{print $10; primary=0}')
[[ "$primary_keys" == "$fingerprint" ]] ||
  die "Anthropic's signing key changed. Expected $fingerprint, got: ${primary_keys:-none}. Verify the new key against Anthropic's documentation before updating scripts/upstream.sh."

sudo install -m 0644 "$key" /usr/share/keyrings/claude-build.asc
source_file=/etc/apt/sources.list.d/claude-build.list
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/claude-build.asc] $base/apt/stable stable main" | sudo tee "$source_file" >/dev/null
# Isolate the package index so only this repository can supply the candidate.
options=(-o "Dir::Etc::sourcelist=$source_file" -o Dir::Etc::sourceparts=-)
sudo apt-get "${options[@]}" -o APT::Get::List-Cleanup=false -o APT::Update::Error-Mode=any update ||
  die "Could not read or verify Anthropic's APT index."
version=$(LC_ALL=C apt-cache "${options[@]}" policy claude-desktop:amd64 | awk '/Candidate:/ {print $2}')
[[ "$version" =~ ^[0-9][0-9A-Za-z.+~-]*$ ]] ||
  die "Anthropic's APT index offers no usable claude-desktop version (got '${version:-nothing}')."
echo "Upstream version: $version"
echo "version=$version" >> "$GITHUB_OUTPUT"
apt-cache "${options[@]}" show "claude-desktop:amd64=$version" > "$RUNNER_TEMP/package.txt"
python3 scripts/manifest.py "$RUNNER_TEMP/package.txt" "$version"
