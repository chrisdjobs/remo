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

Releases are cut from `main` with the script at the repository root. It bumps the version in
`package.json`, `src-tauri/tauri.conf.json`, `src-tauri/Cargo.toml` and `src-tauri/Cargo.lock`,
runs the Rust and frontend checks, commits, creates the `app-vX.Y.Z` tag and pushes both:

```bash
pnpm release 1.3.0                    # from app/
./scripts/release.sh 1.3.0            # same, from the repository root
./scripts/release.sh 1.3.0 --dry-run  # validations and checks only, nothing is written
```

The tag push triggers `release-app.yml`, which creates a single draft Release, builds and signs
the Windows and Linux installers one platform at a time, and publishes the Release once
`latest.json` has both platforms. Installed apps then find the update through
`https://github.com/chrisdjobs/remo/releases/latest/download/latest.json`.

Before the first release in a fork, generate your own updater key pair:

```bash
pnpm tauri signer generate -- -w ~/.tauri/remo.key
```

Put the public key in `src-tauri/tauri.conf.json` (`plugins.updater.pubkey`) and add the private
key and its password as the repository secrets `TAURI_SIGNING_PRIVATE_KEY` and
`TAURI_SIGNING_PRIVATE_KEY_PASSWORD`. Losing the key or its password breaks updates for installed
copies.

## Disclaimer

Downloading copyrighted **content** may be illegal in your country. This tool is for educational purposes only and was created only to show how **it works**. Please support the **creators** by buying their **official releases**.
