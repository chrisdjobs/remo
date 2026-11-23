# Remo (Desktop App) — Spec

## Goal
`Remo` desktop app is a native Tauri 2 application for Windows and Linux that lets Spanish-speaking anime fans search anime, inspect episode lists, and download individual episodes or full seasons into a **Jellyfin-compatible** folder structure—without needing Git Bash, `fzf`, or manual CLI setup. It complements the root-level `remo` bash script (a fork of `ani-es`) and shares the same library folder layout so users can switch between both seamlessly.

## Scope v1 (currently v1.3.0)
- **Multi-source search**: Search and paginate anime from `jkanime.net` and (optionally, disabled by default) `hentaijk.com` (+18), each with its own library folder and Jellyfin layout toggle. **YouTube** (enabled by default) is searched by text with `yt-dlp` or opened directly from a pasted video/playlist URL.
- **Anime details & disk status**: View poster, type (`Película`, etc.), quality, episode list, and which episodes/seasons are already downloaded on disk, plus automatic season detection from series titles (e.g. `"Overlord II"` → `Overlord`, Season 2).
- **YouTube details**: Inspect a video or a playlist (title, channel, thumbnail, duration, entries) and choose **video (MP4)** with an optional resolution cap or **audio only** (MP3/M4A); playlists can be downloaded entirely or by selection.
- **Persistent download queue**: Enqueue individual episodes or full seasons; fresh `.m3u8` stream URLs are resolved right before each download (never cached because tokens expire) and remuxed to `.mp4` without re-encoding via `yt-dlp` + `ffmpeg`.
- **Queue controls & resilience**: Pause/resume individual jobs or all jobs (preserving `.part` fragments), cancel, clear finished, automatic retries (1, 5, 15 min) on transient failures, persistent queue across restarts (`downloads.json`), desktop notifications on completion, and background continuation via system tray icon when closing the window with active downloads.
- **Local library**: Scan each enabled source's library folder (including episodes downloaded by the CLI script), show covers, episode/season counts, disk size, and partial-download warnings, and resolve missing metadata/URLs via `library.json` (kept strictly in app data, never inside the video library folder). YouTube entries are single files at the library root or one folder per playlist.
- **Self-contained tooling**: Detect system `yt-dlp` and `ffmpeg`/`ffprobe`, or download/update official binaries (`yt-dlp` on Windows/Linux, `ffmpeg` on Windows) into app data on first launch.
- **Settings, theming & diagnostics**: Configure concurrent downloads (1–6), per-source enablement/library folder/Jellyfin layout, light/dark/system theme with Fluent accent colors, copyable diagnostics + rolling log (`Settings -> Registro`), and signed auto-updates via GitHub Releases.

## Out of scope (for now)
- **Built-in & external playback**: In-app HLS player (`hls.js`) and launching `mpv` with shared `history.json` (planned as Phase 4 in `../docs/app-tauri.md`).
- **Remote shared scraper rules**: `scraper-rules.json` shared with the bash script (planned as Phase 5).
- **macOS builds**: Currently unsupported / not targeted.
- **Terminal bash script (`../remo`)**: Maintained separately at the repository root.

## Technical decisions
- **Stack / framework + version**:
  - Desktop shell: Tauri `2.x` (`edition = "2024"` Rust backend).
  - Frontend: React `19.1`, TypeScript `~6.0` (strict), Vite `8.x`, Fluent UI React v9 (`@fluentui/react-components` `^9.74`, `@fluentui/react-icons`), `pnpm`.
- **State management / architecture**:
  - Rust core handles all scraping (`reqwest` + `scraper` + `regex`), download orchestration (`tokio` tasks + `Semaphore` + `yt-dlp` subprocesses), library scanning, and persistence; `#[tauri::command]` handlers in `src-tauri/src/lib.rs` stay thin. YouTube search and metadata also go through the bundled `yt-dlp` (`ytsearch`, `--dump-single-json`), not the HTML scraper.
  - Frontend communicates solely through `src/api.ts` (`invoke`) and Tauri `"download-updated"` / `"tools-progress"` events; UI state is held in React components (`App.tsx` and `src/pages/*`), with theme preferences stored in `localStorage`.
- **Backend / data**:
  - No server backend; scrapes public sites (`jkanime.net`, `hentaijk.com`) directly with a cookie-enabled `JkClient` and retry logic for 502/503/504 responses. YouTube is read with `yt-dlp` (no API key, no cookies).
  - Local files in OS app dirs (`io.github.chrisdjobs.remo`): `settings.json` (config dir), `downloads.json`, `library.json`, downloaded `yt-dlp`/`ffmpeg` binaries (data dir), and `remo.log` (log dir).
- **Auth**: None (no user accounts).
- **Hosting / distribution**:
  - Distributed via GitHub Releases (`chrisdjobs/remo`), built in CI (`release-app.yml`) on `app-vX.Y.Z` tags.
  - Signed auto-updates via `tauri-plugin-updater` reading `latest.json` from GitHub Releases.

## Data model (rough)
- `Site`: `"jkanime" | "hentaijk" | "youtube"`
- `SearchResult`: `{ source, title, url, image, kind, status }`
- `AnimeInfo`: `{ source, url, title, image, kind, quality, is_movie, episodes: [{ number, title }] }`
- `YtInfo`: `{ url, title, image, channel, duration, is_playlist, entries: [{ index, id, title, url, duration }] }`
- `YtFormat`: `{ kind: "video", max_height? } | { kind: "audio", codec: "mp3" | "m4a" }`
- `Settings`: `{ concurrent_downloads, sources: Record<Site, { enabled, library_dir, jellyfin_layout }> }`
- `Job`: `{ id, anime, anime_url, is_movie, season, episode, output, status: Status, attempts, video_url? , video_title?, yt_format? }` where `Status` is `queued | resolving | downloading(percent, speed, eta) | paused | waiting(attempt, retry_at, message) | done | skipped | failed(message) | cancelled`
- `IndexEntry` / `LibraryAnime`: cached `{ source, folder, title, url, image }` merged with on-disk `{ name, path, seasons, episodes, partial, bytes, modified }`
- `ToolsStatus`: `{ ytdlp: { source, version }, ffmpeg: { source, version }, can_install_ffmpeg }`

## Constraints
- **Platforms**: Windows 10/11 (`.exe` NSIS current-user installer, `.msi`) and Linux (`.AppImage`, `.deb`, `.rpm`).
- **Clean Jellyfin library**: Only `.mp4` (and in-progress `.part`) video files may be written to the user's library folder; all app state (`library.json`, `downloads.json`, `settings.json`, logs) lives in OS app directories.
- **Cross-OS filenames**: Sanitize filenames using Windows-safe rules on both Windows and Linux so shared libraries work across OSes, preserving Unicode accents.
- **Ephemeral stream URLs & remuxing**: `.m3u8` URLs carry expiring `st`/`e` tokens and must be scraped immediately before downloading; `yt-dlp` remuxes HLS to MP4 without re-encoding.
- **YouTube without API keys**: Search, metadata and downloads use the `yt-dlp` binary the app already manages (`ytsearch`, `--dump-single-json`), so there is no API key, OAuth or cookie store. Single videos go to `<library>/<Title>.<ext>`; playlists to `<library>/<Playlist>/NN - <Title>.<ext>` (never `Season NN`), and `jellyfin_layout` does not apply to YouTube.
- **Scraper fragility**: Depends on upstream HTML/API structure; HTML parser logic (`parse_*` / `extract_*`) must stay pure and covered by offline fixture tests, surfacing clear `Unavailable` / `NotFound` / `SiteChanged` errors.
- **Licensing & distribution**: App is MIT-licensed; `yt-dlp` (Unlicense) and `ffmpeg` (LGPL builds) are downloaded at runtime rather than committed to git. Windows installers are unsigned (users bypass SmartScreen).

## Done criteria
- All Rust checks (`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`) and frontend typecheck/build (`pnpm exec tsc --noEmit`, `pnpm build`) pass cleanly.
- Offline scraper, YouTube JSON parser, library naming/season splitting, download queue persistence/retry, and tool resolution tests pass without network access.
- Users on Windows and Linux can install via GitHub Releases, obtain `yt-dlp`/`ffmpeg` automatically if missing, search anime, queue season/episode downloads into a valid Jellyfin folder layout, queue YouTube videos or playlists (MP4 or audio), pause/resume/close to tray, browse their local library, copy diagnostic logs, and receive signed updates.