#!/usr/bin/env bash
set -euo pipefail
# Runs on the disposable Ubuntu Actions runner.
base=https://downloads.claude.ai/claude-desktop
fingerprint=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
key=$(mktemp)
trap 'rm -f "$key"' EXIT
curl --fail --silent --show-error --location "$base/key.asc" -o "$key"
primary_keys=$(gpg --batch --with-colons --show-keys "$key" |
  awk -F: '$1=="pub"{primary=1} $1=="fpr" && primary{print $10; primary=0}')
[[ "$primary_keys" == "$fingerprint" ]]
sudo install -m 0644 "$key" /usr/share/keyrings/claude-build.asc
source_file=/etc/apt/sources.list.d/claude-build.list
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/claude-build.asc] $base/apt/stable stable main" | sudo tee "$source_file" >/dev/null
# Isolate the package index so only this repository can supply the candidate.
options=(-o "Dir::Etc::sourcelist=$source_file" -o Dir::Etc::sourceparts=-)
sudo apt-get "${options[@]}" -o APT::Update::Error-Mode=any update
version=$(LC_ALL=C apt-cache "${options[@]}" policy claude-desktop:amd64 | awk '/Candidate:/ {print $2}')
[[ "$version" =~ ^[0-9][0-9A-Za-z.+~-]*$ ]]
echo "version=$version" >> "$GITHUB_OUTPUT"
apt-cache "${options[@]}" show "claude-desktop:amd64=$version" > "$RUNNER_TEMP/package.txt"
python3 scripts/manifest.py "$RUNNER_TEMP/package.txt" "$version"
