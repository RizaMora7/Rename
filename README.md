# Rename

A lightweight native **macOS** app for batch-renaming files with **find & replace** and **5 saved presets**, so common renaming tasks become one click.

Built with **Swift + SwiftUI** (AppKit-free), no third-party dependencies.

![Platform](https://img.shields.io/badge/platform-macOS-blue) ![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)

## Features

- **Batch rename** — select multiple files and rename them at once.
- **Find & replace** — replace a text fragment in every selected filename.
- **Live preview** — see the original → new name for every file before applying.
- **5 presets** — save your most-used find/replace pairs and reuse them instantly.
- **Safe** — renames go through a preview step; failures are reported instead of silently skipped.

## Presets

Presets are stored locally (not in the repo) at:

```
~/Library/Application Support/RenameApp/presets.json
```

## Requirements

- macOS (SwiftUI app)
- Xcode 15 or later
- Swift 5.9+

## Getting started

1. Clone the repository:
   ```bash
   git clone https://github.com/<your-username>/Rename.git
   ```
2. Open `Rename/Rename.xcodeproj` in Xcode.
3. Select the **Rename** scheme and press **Run** (⌘R).

## Project structure

```
Rename Project/
├── README.md
├── .gitignore
└── Rename/
    ├── Rename.xcodeproj/          # Xcode project
    ├── Rename/                    # App source
    │   ├── RenameApp.swift        # App entry point
    │   ├── ContentView.swift      # Main UI
    │   ├── RenameEngine.swift     # Find & replace + apply logic
    │   ├── RenamePreset.swift     # Preset model + persistence
    │   └── Assets.xcassets/       # App icon & colors
    ├── RenameTests/               # Unit tests
    └── RenameUITests/             # UI tests
```

## License

Distributed under the **MIT License**. See [LICENSE](LICENSE) for details.
