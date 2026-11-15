#!/usr/bin/env bash
set -euo pipefail
: "${PAGES_URL:?}" "${GNUPGHOME:?}"
mapfile -t fingerprints < <(gpg --batch --with-colons --list-secret-keys |
  awk -F: '$1=="sec"{primary=1} $1=="fpr" && primary{print $10; primary=0}')
[[ ${#fingerprints[@]} == 1 ]]
key=${fingerprints[0]}
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
mkdir -p public build
flatpak-builder --user --install-deps-from=flathub --assumeyes --repo=public/repo --gpg-sign="$key" build/app build-manifest.json
flatpak build-update-repo --gpg-sign="$key" public/repo
gpg --export "$key" > "$RUNNER_TEMP/public.gpg"
# Exercise the install-time download and extractor against the signed remote.
flatpak remote-add --user --gpg-import="$RUNNER_TEMP/public.gpg" smoke "file://$PWD/public/repo"
flatpak install --user -y smoke com.anthropic.Claude//stable
flatpak run --command=sh com.anthropic.Claude -ec 'command -v zypak-wrapper && test -x /app/extra/claude-desktop/claude-desktop'
cat > public/claude.flatpakrepo <<REPO
[Flatpak Repo]
Title=Claude Desktop ($GITHUB_REPOSITORY)
Url=${PAGES_URL%/}/repo/
GPGKey=$(base64 -w0 "$RUNNER_TEMP/public.gpg")
REPO
cp "$RUNNER_TEMP/build-id" public/build-id
echo "Remote: ${PAGES_URL%/}/claude.flatpakrepo" >> "$GITHUB_STEP_SUMMARY"
echo "GPG: \`$key\`" >> "$GITHUB_STEP_SUMMARY"
