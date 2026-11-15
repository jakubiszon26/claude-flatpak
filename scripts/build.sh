#!/usr/bin/env bash
# Builds, signs, and smoke-tests the Flatpak remote, then writes everything
# GitHub Pages serves into public/. Runs on the GitHub Actions runner.
set -euo pipefail

die() {
  echo "::error::$*" >&2
  exit 1
}

: "${PAGES_URL:?PAGES_URL must be set to the GitHub Pages base URL}"
: "${GNUPGHOME:?GNUPGHOME must point at a keyring holding the signing key}"
: "${VERSION:?VERSION must be set to the upstream Claude Desktop version}"
[[ -f build-manifest.json ]] || die "build-manifest.json is missing. Run scripts/upstream.sh first."

app_id=com.anthropic.Claude
pages_url=${PAGES_URL%/}

mapfile -t fingerprints < <(gpg --batch --with-colons --list-secret-keys |
  awk -F: '$1=="sec"{primary=1} $1=="fpr" && primary{print $10; primary=0}')
[[ ${#fingerprints[@]} == 1 ]] ||
  die "Expected exactly one signing key in FLATPAK_GPG_PRIVATE_KEY, found ${#fingerprints[@]}."
key=${fingerprints[0]}

flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
mkdir -p public build
flatpak-builder --user --install-deps-from=flathub --assumeyes --repo=public/repo --gpg-sign="$key" build/app build-manifest.json
flatpak build-update-repo --gpg-sign="$key" public/repo
gpg --export "$key" > "$RUNNER_TEMP/public.gpg"

# Licence guard. Claude Desktop is proprietary, so the published remote may
# carry only this project's launcher and metadata. Users download the app
# itself from Anthropic at install time.
if [[ -d build/app/files/extra && -n "$(ls -A build/app/files/extra)" ]]; then
  die "The build contains extra-data payload. Refusing to publish Anthropic's files."
fi
leaked=$(find build/app/files public \( -name '*.deb' -o -name '*.asar' \) -print -quit)
[[ -z "$leaked" ]] || die "Proprietary file found in the build output: $leaked"
repo_mb=$(du -sm public/repo | cut -f1)
(( repo_mb <= 64 )) ||
  die "The repository is ${repo_mb} MB. It should hold a few MB of packaging, so something was bundled by mistake."

# Smoke test: install from the signed remote the way a user would, which
# downloads the package from Anthropic and runs apply_extra.
flatpak remote-add --user --gpg-import="$RUNNER_TEMP/public.gpg" smoke "file://$PWD/public/repo"
flatpak install --user -y smoke "$app_id//stable"
flatpak run --command=sh "$app_id" -ec '
  command -v zypak-wrapper >/dev/null
  test -x /app/extra/claude-desktop/claude-desktop
  test -x /app/libexec/claude-flatpak/host-exec
  test -x /app/libexec/claude-flatpak/link-host-tools
' || die "Smoke test failed: the installed app is incomplete."
icon="$HOME/.local/share/flatpak/exports/share/icons/hicolor/256x256/apps/$app_id.png"
[[ -f "$icon" ]] || echo "::warning::The application icon was not exported at install time."

gpg_key=$(base64 -w0 "$RUNNER_TEMP/public.gpg")
cat > public/claude.flatpakrepo <<REPO
[Flatpak Repo]
Title=Claude Desktop (unofficial Flatpak)
Comment=Community packaging of Claude Desktop from $GITHUB_REPOSITORY
Homepage=https://github.com/$GITHUB_REPOSITORY
Url=$pages_url/repo/
GPGKey=$gpg_key
REPO
cat > public/claude-desktop.flatpakref <<REF
[Flatpak Ref]
Name=$app_id
Branch=stable
IsRuntime=false
Title=Claude Desktop (unofficial Flatpak)
Comment=Desktop application for Claude.ai, packaged by the community
Description=Community-maintained Flatpak packaging. The application is downloaded directly from Anthropic during installation. Not affiliated with or supported by Anthropic.
Homepage=https://github.com/$GITHUB_REPOSITORY
Url=$pages_url/repo/
SuggestRemoteName=claude-desktop
RuntimeRepo=https://dl.flathub.org/repo/flathub.flatpakrepo
GPGKey=$gpg_key
REF
sed -e "s|@PAGES_URL@|$pages_url|g" \
    -e "s|@REPO@|$GITHUB_REPOSITORY|g" \
    -e "s|@VERSION@|$VERSION|g" \
    -e "s|@FINGERPRINT@|$key|g" \
    -e "s|@UPDATED@|$(date -u +%Y-%m-%d)|g" \
    site/index.html > public/index.html
cp "$RUNNER_TEMP/build-id" public/build-id

{
  echo "### Claude Desktop $VERSION published"
  echo "- Install page: $pages_url/"
  echo "- Remote: $pages_url/claude.flatpakrepo"
  echo "- Signing key: \`$key\`"
} >> "$GITHUB_STEP_SUMMARY"
