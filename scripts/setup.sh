#!/usr/bin/env bash
# One-time setup for a fork: enables GitHub Pages, creates a signing key,
# stores it as an Actions secret, and starts the first build.
# Run it locally from a clone of your fork: bash scripts/setup.sh
set -euo pipefail

die() {
  echo "Error: $*" >&2
  exit 1
}

for tool in gh gpg gpgconf; do
  command -v "$tool" >/dev/null ||
    die "'$tool' is not installed. On Fedora: sudo dnf install gh gnupg2"
done
gh auth status >/dev/null 2>&1 || die "GitHub CLI is not signed in. Run: gh auth login"
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner) ||
  die "Run this script inside a clone of your fork."
[[ $(gh repo view "$repo" --json viewerPermission --jq .viewerPermission) == ADMIN ]] ||
  die "You need admin access to $repo to configure Pages and secrets."

echo "==> Enabling GitHub Pages (deploy from Actions) for $repo"
if gh api "repos/$repo/pages" >/dev/null 2>&1; then
  gh api --method PUT "repos/$repo/pages" -f build_type=workflow --silent
else
  gh api --method POST "repos/$repo/pages" -f build_type=workflow --silent
fi

names=$(gh secret list -R "$repo" --json name --jq '.[].name')
if grep -Fxq FLATPAK_GPG_PRIVATE_KEY <<< "$names"; then
  echo "==> Signing key already configured, keeping it"
else
  echo "==> Creating a signing key and storing it as FLATPAK_GPG_PRIVATE_KEY"
  umask 077
  export GNUPGHOME
  GNUPGHOME=$(mktemp -d)
  trap 'gpgconf --kill all; rm -rf "$GNUPGHOME"' EXIT
  gpg --batch --quiet --passphrase '' --quick-generate-key "Flatpak ($repo)" rsa3072 sign 0
  gpg --batch --armor --export-secret-keys | gh secret set FLATPAK_GPG_PRIVATE_KEY --repo "$repo"
  echo "Public key fingerprint (also shown on your install page):"
  gpg --batch --with-colons --fingerprint | awk -F: '$1=="fpr"{print "  " $10; exit}'
  echo "The private key now exists only in the GitHub secret. See README for backups."
fi

echo "==> Starting the first build"
gh workflow enable build.yml -R "$repo"
gh workflow run build.yml -R "$repo"
owner=${repo%%/*}
echo
echo "Done. Follow the build at:"
echo "  https://github.com/$repo/actions/workflows/build.yml"
echo "When it finishes, your install page will be at:"
echo "  https://${owner,,}.github.io/${repo#*/}/"
