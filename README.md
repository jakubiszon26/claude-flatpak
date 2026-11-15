# Claude Desktop Flatpak

An unofficial, community-maintained Flatpak of [Claude Desktop](https://claude.ai/download) for x86_64 Linux. It works on any distribution with Flatpak and is tested on Fedora.

- **One-step install** from a signed remote, with no GitHub account or build tools needed.
- **Automatic updates.** A daily job picks up new Claude Desktop releases, usually within a day.
- **The app comes straight from Anthropic.** This project hosts only a launcher. Flatpak downloads Claude Desktop from Anthropic's servers on your machine and verifies its SHA-256 checksum.
- **Claude Code works with your tools.** Git, the GitHub CLI, and other commands installed on your system are available inside the app.

> [!NOTE]
> This project is not affiliated with, endorsed by, or supported by Anthropic. Anthropic officially supports Claude Desktop on Debian-based distributions.

## Install

Open the [install page](https://jakubiszon26.github.io/claude-flatpak/) and choose **Install Claude Desktop**, or run:

```bash
flatpak install --user https://jakubiszon26.github.io/claude-flatpak/claude-desktop.flatpakref
```

Flatpak offers to add Flathub if you don't have it yet, because the runtime comes from there. If the `flatpak` command is missing, follow the [setup guide for your distribution](https://flatpak.org/setup/) first.

Start Claude from your application menu, or run:

```bash
flatpak run com.anthropic.Claude
```

## Update and uninstall

Software centers update the app together with your other Flatpaks. To update manually:

```bash
flatpak update --user com.anthropic.Claude
```

To remove the app and its remote:

```bash
flatpak uninstall --user com.anthropic.Claude
```

```bash
flatpak remote-delete --user claude-desktop
```

<details>
<summary>Upgrading from the <code>claude-personal</code> remote</summary>

Earlier instructions named the remote `claude-personal`. It points at the same address and keeps receiving updates, so no action is needed. To switch to the new name, remove the old remote with `flatpak remote-delete --user --force claude-personal` and install again with the command above. Your settings and sign-in are kept.

</details>

## Permissions

This Flatpak is a convenient way to install and update Claude Desktop. It is not a security sandbox. The app can:

- read and write every file your user account can (`--filesystem=host`), so Claude Code can open projects anywhere,
- run commands on your system outside the sandbox (`--talk-name=org.freedesktop.Flatpak`), so Claude Code can use your Git, GitHub CLI, compilers, and containers,
- use the network, your system keyring, notifications, and the tray.

Host commands are added at the end of `PATH`, so tools bundled with the Flatpak runtime take precedence. They run with your system's environment, not the app's.

You can tighten this with [Flatseal](https://flathub.org/apps/com.github.tchx84.Flatseal) or from a terminal. To stop the app from running host commands:

```bash
flatpak override --user --no-talk-name=org.freedesktop.Flatpak com.anthropic.Claude
```

To limit file access to a single folder (here `~/Projects`):

```bash
flatpak override --user --nofilesystem=host --filesystem=~/Projects com.anthropic.Claude
```

Cowork's virtual machine support (QEMU/KVM) is not configured by this package.

## How it works

Claude Desktop is proprietary software, so this project does not redistribute it.

1. Every day at 05:27 UTC, GitHub Actions reads Anthropic's signed APT index and checks the signing key against a pinned fingerprint.
2. If there is a new release, the workflow builds a small Flatpak containing only this repository's launcher and helper scripts. The Claude Desktop package is recorded as [extra data](https://docs.flatpak.org/en/latest/module-sources.html#extra-data): a download address at `downloads.claude.ai`, a size, and a SHA-256 checksum.
3. The build is signed, installed from a test remote on the runner, checked, and published to GitHub Pages. The build fails if any file from Anthropic's package ends up in the published output.
4. When you install or update, Flatpak downloads the package from Anthropic, verifies the checksum, and unpacks it locally. The application icon is taken from that package in the same step.

## Host your own remote

Fork the repository if you want to control the packaging and sign updates with your own key.

1. Create a public fork. Open **Actions** in the fork and enable workflows if prompted.
2. Install the tools and sign in with an account that has admin access to the fork. On Fedora:

   ```bash
   sudo dnf install gh git gnupg2
   ```

   ```bash
   gh auth login
   ```

3. Clone the fork and run the setup script, replacing `YOUR_USERNAME`:

   ```bash
   gh repo clone YOUR_USERNAME/claude-flatpak && cd claude-flatpak && bash scripts/setup.sh
   ```

   The script enables GitHub Pages, creates a dedicated signing key, stores it in the `FLATPAK_GPG_PRIVATE_KEY` Actions secret, and starts the first build. Running it again keeps the existing key.

4. When the **build** and **publish** jobs finish, your install page is live at `https://YOUR_USERNAME.github.io/claude-flatpak/`, with the same install button and command as above.

Notes for maintainers:

- **Backing up the key.** The generated private key exists only in the GitHub secret. If you want a backup, create a passphrase-less signing key yourself and store its ASCII-armored private key in `FLATPAK_GPG_PRIVATE_KEY` before running setup.
- **Forcing a rebuild.** Choose **Run workflow** in the **Actions** tab.
- **Staying active.** GitHub disables scheduled workflows in public repositories after 60 days without activity. Re-enable the workflow in **Actions** when that happens.
- **Getting packaging changes.** Use **Sync fork** on GitHub.

## Credits

- Based on [Gordon Messmer's Flatpak packaging](https://github.com/gordonmessmer/com.anthropic.Claude).
- [Anthropic's Linux documentation](https://code.claude.com/docs/en/desktop-linux) for the APT repository and signing key fingerprint.
- [Flatpak documentation](https://docs.flatpak.org/en/latest/hosting-a-repository.html) on hosting and signing a repository.

## License

The packaging scripts in this repository are released under the [MIT License](LICENSE). Claude Desktop itself is proprietary software owned by Anthropic PBC and is subject to [Anthropic's terms](https://www.anthropic.com/legal). Claude is a trademark of Anthropic PBC.
