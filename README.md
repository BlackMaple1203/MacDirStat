<div align="center">

<img src="logo.png" width="120" alt="MacDirStat icon" />

<h1>MacDirStat</h1>

<p><strong>See where your disk space went.</strong><br/>
A fast, beautiful macOS disk usage visualizer — built entirely in Swift.</p>

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.10-F05138?style=flat-square&logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](./LICENSE)
[![App Store](https://img.shields.io/badge/App%20Store-$4.99-0D96F6?style=flat-square&logo=appstore)](https://apps.apple.com)

</div>

---

![MacDirStat demo](demo.gif)

---

## What it does

MacDirStat scans any folder and turns your filesystem into an interactive sunburst chart — every ring is a depth level, every arc is a file or folder, sized by disk usage. Hover to inspect. Click to drill in. Right-click to delete.

## Features

- **Sunburst visualization** — depth rings, color-coded by file type (video, code, images, archives…)
- **Spotlight hover** — everything else fades when you hover; selected files pulse with a glow
- **Force Touch haptics** — soft tap for small files, triple thud for multi-GB ones
- **Drill navigation** — click any folder to zoom in, click back to go up
- **Duplicate detection** — finds identical files by content hash, shows wasted space per group
- **One-click cleanup** — keep one copy, trash the rest — or delete file by file
- **File list panel** — sortable tree view beside the chart, toggle to give the chart full width
- **File type breakdown** — top file types with a searchable list of all types
- **Move to Trash** — right-click any arc or row to trash it, chart refreshes instantly
- **CSV export** — dump the full scan as a spreadsheet
- **Settings** — toggle haptic feedback on/off

## Screenshots

| Full view | File types | Expanded types |
|---|---|---|
| ![](Screenshots/Screenshot%202026-05-03%20at%2012.01.37%E2%80%AFPM.png) | ![](Screenshots/Screenshot%202026-05-03%20at%2012.02.00%E2%80%AFPM.png) | ![](Screenshots/Screenshot%202026-05-03%20at%2012.02.07%E2%80%AFPM.png) |

## Install

**Mac App Store** *(supports the project)*

> [Download on the App Store](https://apps.apple.com) — $4.99

**Build from source**

```bash
git clone https://github.com/Ti-03/MacDirStat.git
cd MacDirStat
swift run
```

Requires macOS 14+ and Xcode 15+.

## Tech

Pure Swift + SwiftUI — no Electron, no web views, no dependencies.

| Layer | What |
|---|---|
| Scanner | POSIX `opendir`/`fstatat` with async task groups — parallel, cancellable |
| Layout | Custom sunburst partition algorithm (band-width from view size) |
| Renderer | SwiftUI `Canvas` — draws 1,000+ arcs at 30 fps |
| Haptics | `NSHapticFeedbackManager` — intensity scales with file size |
| Duplicates | SHA-256 content hashing on a background actor |

## Privacy

MacDirStat collects zero data. No network access. No analytics. No tracking. Everything runs on your device. [Full privacy policy](https://ti-03.github.io/MacDirStat/privacy.html).

## Contributing

PRs welcome. Open an issue first for anything beyond a bug fix.

## License

MIT — free to use, modify, and distribute.  
If you find it useful, the [App Store version](https://apps.apple.com) is the best way to say thanks.

---

<div align="center">
Built with ❤️ by &nbsp;·&nbsp; <a href="https://ti0.me/">Ti</a> &nbsp;·&nbsp; 
</div>
