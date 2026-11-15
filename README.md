# Claude Desktop for Fedora

Install Claude Desktop on **Fedora x86_64** from this community-maintained Flatpak remote. Anyone can use the public remote without a GitHub account or a fork. GitHub Pages hosts the launcher, Electron base files, and signed package metadata. During installation and updates, Flatpak downloads the Claude Desktop package directly from Anthropic and verifies its SHA-256 checksum.

## Install and run

Add Flathub for the runtime, then install Claude Desktop from this project's signed remote.

```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --user --if-not-exists claude-personal https://jakubiszon26.github.io/claude-flatpak/claude.flatpakrepo
flatpak install --user claude-personal com.anthropic.Claude
flatpak run com.anthropic.Claude
```

If you previously installed a standalone bundle with the same app ID, run `flatpak install --user --reinstall claude-personal com.anthropic.Claude` after adding the remote. To check which remote supplies updates, run `flatpak info --user --show-origin com.anthropic.Claude`. The expected origin is `claude-personal`.

## Update

```bash
flatpak update --user com.anthropic.Claude
```

GitHub Actions checks Anthropic's signed APT index daily at 05:27 UTC. It rebuilds the Flatpak when the upstream package or the repository revision changes. Before publishing, the runner installs the app from a signed test remote and checks that the launcher and executable are present.

## Host your own signed remote

Fork this repository if you want to control the packaging and sign updates with your own key.

1. Create a public fork. Open **Actions** in your fork and enable workflows if prompted.
2. Install the setup tools on Fedora and sign in with a GitHub account that has admin access to the fork.

   ```bash
   sudo dnf install gh git gnupg2 flatpak
   gh auth login
   ```

3. Clone your fork and run the setup script. Replace `YOUR_USERNAME` with your GitHub username and adjust the repository name if you renamed the fork.

   ```bash
   gh repo clone YOUR_USERNAME/claude-flatpak
   cd claude-flatpak
   bash scripts/setup.sh
   ```

   The script configures Pages to deploy from Actions, generates a dedicated signing key, prints its public fingerprint, and stores the private key in the Actions secret `FLATPAK_GPG_PRIVATE_KEY`. Running setup again preserves the existing secret. If you need a backup, generate and back up your own dedicated signing key first, then set the secret to its ASCII-armored private key before running setup. The workflow requires a key without a passphrase.

4. Wait for both **build** and **publish** to succeed. The build summary lists your fork's `claude.flatpakrepo` URL and signing key fingerprint. Add your fork under a distinct remote name and install from it. For example, with the default Pages address:

   ```bash
   flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
   flatpak remote-add --user claude-fork https://YOUR_USERNAME.github.io/claude-flatpak/claude.flatpakrepo
   flatpak install --user claude-fork com.anthropic.Claude
   ```

To force a rebuild, choose **Run workflow** in the **Actions** tab. GitHub may disable scheduled workflows after 60 days of inactivity in a public repository. You can re-enable the workflow in **Actions** and pull packaging changes from upstream with **Sync fork**.

## Permissions and compatibility

The app has network access, can communicate with the system credential store, and can access host files with your user's permissions through `--filesystem=host`. It runs inside the Flatpak environment, so tools installed on Fedora with DNF may require additional integration. The packaging does not configure QEMU/KVM for Cowork. Anthropic officially supports Claude Desktop on Debian-based Linux distributions.

## References

- [Anthropic's Linux requirements, APT repository, and signing key fingerprint](https://code.claude.com/docs/en/desktop-linux)
- [Gordon Messmer's original Flatpak packaging](https://github.com/gordonmessmer/com.anthropic.Claude)
- [Hosting and signing a Flatpak repository](https://docs.flatpak.org/en/latest/hosting-a-repository.html)
