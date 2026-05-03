<div align="center">

# MacDirStat

**Understand your disk in seconds.**  
A fast, beautiful macOS disk usage visualizer — built entirely in Swift.

<!-- Replace with a real screenshot -->
![MacDirStat screenshot](./assets/screenshot.png)

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.10-F05138?style=flat-square&logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](./LICENSE)
[![App Store](https://img.shields.io/badge/App%20Store-Download-0D96F6?style=flat-square&logo=appstore)](https://apps.apple.com)

</div>

---

## What it does

MacDirStat scans any folder and turns your file system into an interactive sunburst chart — every ring is a depth level, every arc is a file or folder, sized by disk usage. Hover anything to see details. Click to drill in. Feel the weight of large files through your trackpad.

## Features

- **Sunburst visualization** — depth rings, color-coded by file type (video, code, images, archives…)
- **Spotlight hover** — everything else fades out when you hover an arc; large files pulse
- **Force Touch haptics** — soft tap for small files, double/triple thud for multi-GB ones
- **Drill navigation** — click any folder to zoom in, click the center to go back
- **File list panel** — sortable tree view beside the chart, toggle to give the chart full width
- **Extension legend** — top-5 type pills with a searchable "show all" popover for 1000s of types
- **Duplicate detection** — finds identical files by content hash, marks them on the chart
- **Move to Trash** — right-click any arc or row to trash it, chart refreshes instantly
- **CSV export** — dump the full scan as a spreadsheet

## Screenshots

| Sunburst chart | File list | Extension legend |
|---|---|---|
| ![chart](./assets/chart.png) | ![list](./assets/list.png) | ![legend](./assets/legend.png) |

## Install

**Mac App Store** *(easiest — supports the project)*

> Coming soon — [notify me](https://github.com/Ti-03/MacDirStat/issues/1)

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
| Renderer | SwiftUI `Canvas` — draws 1 000+ arcs at 30 fps |
| Haptics | `NSHapticFeedbackManager` — intensity scales with file size |
| Duplicates | SHA-256 content hashing on a background actor |

## Contributing

PRs welcome. Open an issue first for anything beyond a bug fix so we can agree on direction.

## License

MIT — free to use, modify, and distribute.  
If you find it useful, the [App Store version](https://apps.apple.com) is the best way to say thanks.

---

<div align="center">
Made with care on a Mac &nbsp;·&nbsp; <a href="https://github.com/Ti-03/MacDirStat/issues">Report a bug</a>
</div>
