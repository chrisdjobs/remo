# Remo — desktop app

Desktop app (Tauri 2 + React + Fluent UI) for Windows and Linux. It does the same as the
terminal script at the repository root, without needing bash or external tools.
Design and phases: [`../docs/app-tauri.md`](../docs/app-tauri.md).

## Features

- Multi-source search (jkanime and HentaiJK, the latter disabled by default).
- Persistent download queue with pause/resume, retries, notifications and tray icon.
- Local library view with covers, seasons, sizes and partial-download warnings.
- Optional Jellyfin folder layout (`Season 01/<Anime> - S01E01.mp4`).
- Light/dark theme, bundled/downloadable `yt-dlp` and `ffmpeg`, signed auto-updates.

## Development

Requirements: stable Rust (`rustup`), Node.js LTS, pnpm and, on Linux, the
[Tauri dependencies](https://tauri.app/start/prerequisites/) (`webkit2gtk-4.1`, etc.).

```bash
cd app
pnpm install
pnpm tauri dev      # app in development mode with hot reload
cargo test --manifest-path src-tauri/Cargo.toml   # core tests
pnpm tauri build    # installers in src-tauri/target/release/bundle/
```

## Where it stores its data

The app identifier is `io.github.chrisdjobs.remo`:

| | Windows | Linux |
|---|---|---|
| Settings | `%APPDATA%\io.github.chrisdjobs.remo\` | `~/.config/io.github.chrisdjobs.remo/` |
| Queue, library index, tools | `%APPDATA%\io.github.chrisdjobs.remo\` | `~/.local/share/io.github.chrisdjobs.remo/` |
| Log | `%LOCALAPPDATA%\io.github.chrisdjobs.remo\logs\` | `~/.local/share/io.github.chrisdjobs.remo/logs/` |

## Publishing

Create and push a tag `app-vX.Y.Z`; the `release-app.yml` workflow builds the Windows and
Linux installers and attaches them to a draft Release.
First, bump the version in `src-tauri/tauri.conf.json` and `src-tauri/Cargo.toml`.

Before the first release, replace the placeholder values:

- **Updater signing key:** generate the key pair and configure it:

  ```bash
  pnpm tauri signer generate -- -w ~/.tauri/remo.key
  ```

  Put the public key in `src-tauri/tauri.conf.json` (`plugins.updater.pubkey`, it currently
  holds the placeholder `REPLACE_WITH_YOUR_TAURI_SIGNING_PUBLIC_KEY`) and add the private key
  and its password as the repository secrets `TAURI_SIGNING_PRIVATE_KEY` and
  `TAURI_SIGNING_PRIVATE_KEY_PASSWORD`. Run 'pnpm tauri signer generate -- -w ~/.tauri/remo.key' before the first release.

## Disclaimer

Downloading copyrighted **content** may be illegal in your country. This tool is for educational purposes only and was created only to show how **it works**. Please support the **creators** by buying their **official releases**.
