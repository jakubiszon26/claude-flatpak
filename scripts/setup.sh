#!/usr/bin/env bash
# Run locally, in an authenticated clone of your fork.
set -euo pipefail
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
echo "Configuring GitHub Pages and Actions in $repo"
if gh api "repos/$repo/pages" >/dev/null 2>&1; then
  gh api --method PUT "repos/$repo/pages" -f build_type=workflow --silent
else
  gh api --method POST "repos/$repo/pages" -f build_type=workflow --silent
fi
names=$(gh secret list -R "$repo" --json name --jq '.[].name')
if ! grep -Fxq FLATPAK_GPG_PRIVATE_KEY <<< "$names"; then
  umask 077
  export GNUPGHOME
  GNUPGHOME=$(mktemp -d)
  trap 'gpgconf --kill all; rm -rf "$GNUPGHOME"' EXIT
  gpg --batch --passphrase '' --quick-generate-key "Flatpak ($repo)" rsa3072 sign 0
  gpg --batch --armor --export-secret-keys | gh secret set FLATPAK_GPG_PRIVATE_KEY --repo "$repo"
  gpg --fingerprint
fi
gh workflow enable build.yml -R "$repo"
gh workflow run build.yml -R "$repo"
echo "https://github.com/$repo/actions/workflows/build.yml"
