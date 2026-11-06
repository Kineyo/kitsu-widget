# AGENTS.md — Developer & AI Agent Guide for Kitsu

> **Purpose:** This document is the definitive technical guide for AI agents, contributors, and core developers working on, modifying, and building Kitsu.

---

## 1. Project Overview & System Philosophy

This project is a high-performance, ultra-lightweight desktop AI companion and media assistant built on a **Hybrid C/C++17 + Lua 5.3 + GTK3/Cairo** architecture. It is designed to reside permanently on the user's desktop as an interactive floating circular bubble with zero bloat and high responsiveness.

### Core Pillars
1. **Hybrid Execution Engine:**
   - **Performance-critical tasks in C++17:** Native X11/Wayland text-selection hooks (`XFixes`), sub-millisecond cursor tracking, magnetic screen geometry clamping, and MPRIS2 D-Bus IPC.
   - **Page cache control in POSIX C99:** A specialized `LD_PRELOAD` memory guard (`lib/libqwen_mmap_guard.so`) that periodically invalidates clean file-backed model pages via `posix_fadvise(..., POSIX_FADV_DONTNEED)`.
   - **Application logic & UI orchestration in Lua 5.3:** GTK 3.0 via LGI with custom Cairo drawing routines, reactive state animations, and modular skill dispatch.
2. **Strict Memory Budget ($\le 500\text{ MB RAM}$):**
   - The entire stack—including the running widget, GTK window hierarchy, and the embedded `llama.cpp` inference server loaded with conversational and grammar models—is engineered to operate under a hard ceiling of 500 MB VmRSS.
3. **Zero-Emoji Visual Design System:**
   - Emojis are strictly prohibited in the user interface. All visual indicators, controls, and status badges are rendered through pure mathematical vector geometry in Cairo (`lib/icons.lua` and `assets/icons/`) paired with clean typographic labels.
4. **Dual Inference Engine:**
   - **Local Inference:** Embedded `llama-server` process hosting quantized GGUF models (`qwen3.0-0.8b.gguf` for dialogue and `es-grammar.gguf` for instant Spanish grammar and text improvement).
   - **Cloud API Fallback:** Seamless switching to OpenAI, Google Gemini, Anthropic, or OpenRouter with encrypted local key storage (`0600` permissions).
5. **Real-Time Multimedia & Synced Lyrics:**
   - Autonomous MPRIS2 media controller supporting YouTube Music and Spotify, coupled with asynchronous LRCLIB synchronization and microsecond lyric-bubble docking.

---

## 2. Codebase Map & Directory Structure

```text
.
├── CMakeLists.txt                 # Multiplatform CMake build definition (C++17 / C99)
├── install.sh                     # System-wide or local installer with automatic model verification
├── run.sh                         # Developer launch harness with environment preloading
├── LICENSE                        # MIT License
├── README.md                      # Public documentation & user manual
├── AGENTS.md                      # This technical reference for agents & developers
├── CONTRIBUTING.md                # Contribution guidelines and coding conventions
├── RELEASE_NOTES.md               # Version history and migration changelog
│
├── assets/                        # Graphical assets & pre-rendered UI graphics
│   ├── avatar_source.jpg          # Clean high-resolution master source artwork
│   ├── avatar.jpg / avatar.png    # Sanitized base avatar formats (no EXIF metadata)
│   ├── icon.png                   # 256x256 circular application icon with obsidian halo
│   ├── icons/                     # 48x48 geometric vector icons (play, pause, chat, etc.)
│   └── sprites/                   # Reactive state sprites (.png and .webp)
│       ├── idle.*                 # Default quiescent state (Violet halo)
│       ├── hover.*                # Mouse hover excitation (Lavender halo)
│       ├── chatting.*             # AI generation / dialogue active (Cyan halo)
│       ├── thinking.*             # Inference deliberation (Amber pulse)
│       ├── music.*                # Track playback active (Magenta glow)
│       ├── grammar.*              # Text selection / grammar correction (Emerald glow)
│       └── error.*                # Subsystem or network warning (Coral alert)
│
├── bin/                           # Executables and launcher scripts
│   ├── kitsu                      # Primary shell launcher (sets LUA_PATH, LUA_CPATH, LD_LIBRARY_PATH)
│   ├── kitsu-bin                  # Native C++ binary launcher (alternative entrypoint)
│   ├── kitsu-power                # Clean CLI utility for status, power on/off, restart
│   ├── kitsu-avatar               # CLI utility to crop, resize, and apply custom widget images
│   ├── qwen-widget                # Compatibility alias for kitsu
│   └── llama-server               # Embedded llama.cpp binary (platform-specific)
│
├── lib/                           # Lua runtime modules (orchestration & UI)
│   ├── main.lua                   # Application bootstrap, LGI initialization, event loop
│   ├── config.lua                 # Settings schema, design constants, JSON persistence
│   ├── avatar_customizer.lua      # Lua module to crop (1:1) and resize user images for the widget
│   ├── avatar_manager.lua         # Compatibility alias to avatar_customizer
│   ├── widget.lua                 # Floating circular window, Cairo paint routines, drag & snap
│   ├── chat.lua                   # Chat panel, conversation history, 6-tab settings manager
│   ├── player.lua                 # Mini-player docked to main bubble (media controls & progress)
│   ├── mpris.lua                  # Hybrid C++/Lua bridge for media metadata and control
│   ├── lyrics.lua                 # Asynchronous LRCLIB client with local caching & offset
│   ├── lyrics_bubble.lua          # Lightweight floating header displaying synchronized lyrics
│   ├── text_popup.lua             # Cursor-following grammar and translation action menu
│   ├── ai_engine.lua              # Unified inference engine (llama.cpp HTTP & Cloud REST)
│   ├── model_manager.lua          # GGUF integrity checker, magic byte verifier, downloader
│   ├── icons.lua                  # Vector icon renderer in pure Cairo (zero emoji rule)
│   ├── utils.lua                  # Geometry math, screen clamping, color helpers, cache
│   ├── animator.lua               # Micro-animation tweening engine
│   ├── bubbles.lua                # Telemetry and fact bubbles
│   ├── dbus_listener.lua          # Freedesktop notification watcher
│   ├── fetchers.lua               # Telemetry providers (crypto, weather, rates, CPU/RAM)
│   ├── json.lua                   # Pure Lua JSON parser/encoder
│   ├── openclaw_agent.lua         # ReAct agent loop with tool-calling support
│   └── skills/                    # Modular agent capabilities
│       ├── manager.lua            # Skill loader and dispatcher
│       ├── writing.lua            # Grammar, spelling, tone formalization prompts
│       ├── system_info.lua        # Real-time hardware and process telemetry
│       ├── bash.lua               # Sandboxed shell command execution
│       ├── media_control.lua      # Playback automation
│       ├── web_search.lua         # DuckDuckGo fast queries
│       ├── app_launch.lua         # Desktop application launcher
│       ├── screenshot.lua         # Full desktop capture
│       ├── notify.lua             # Desktop notifications
│       └── openclaw_gateway.lua   # IPC gateway integration
│
├── models/                        # Quantized GGUF model storage
│   ├── qwen3.0-0.8b.gguf          # Quantized conversational chat model (~500MB)
│   └── es-grammar.gguf            # Quantized Spanish syntax/grammar model (~300MB)
│
├── packaging/                     # Distribution specs for downstream packaging
│   ├── arch/PKGBUILD              # Arch Linux package specification
│   ├── macos/build_dmg.sh         # macOS .dmg and .pkg creation script
│   └── windows/installer.nsi      # NSIS Windows installer script
│
├── scripts/                       # Developer maintenance scripts
│   ├── generate_sprites.py        # Python asset generator (processes source artwork)
│   └── build_packages.sh          # Linux .deb and .tar.gz packaging script
│
└── src/                           # Native C and C++ source code
    ├── qwen_native.cpp            # C++17 native hooks, D-Bus MPRIS2, X11/XFixes, memory trim
    ├── qwen_mmap_guard.c          # C99 POSIX mmap page eviction guard (LD_PRELOAD)
    ├── qwen_runner.cpp            # Multiplatform binary launcher
    └── include/                   # Lua C API headers and llama.h stubs
```

---

## 3. Toolchain & Compilation

### System Prerequisites

#### Debian / Ubuntu / Pop!_OS
```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential cmake pkg-config g++ gcc make \
    libglib2.0-dev libx11-dev libxfixes-dev libxi-dev \
    lua5.3 liblua5.3-dev lua-lgi \
    gir1.2-gtk-3.0 gir1.2-gdkpixbuf-2.0 gir1.2-pango-1.0 \
    curl python3 python3-pil
```

#### Arch Linux / Manjaro / EndeavourOS
```bash
sudo pacman -Syu --needed \
    base-devel cmake gcc pkgconf \
    lua53 lua53-lgi gtk3 glib2 \
    libx11 libxfixes libxi curl python-pillow
```

#### macOS (Apple Silicon / Intel)
```bash
brew install cmake pkg-config lua@5.3 gobject-introspection gtk+3 curl python3
pip3 install pillow
```

### Compiling Native Modules via CMake

Run the CMake configure and build pipeline from the repository root:

```bash
# 1. Configure the build directory
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release

# 2. Compile targets in parallel
cmake --build build -j$(nproc)
```

### Build Artifacts Produced
- `lib/qwen_native.so` (Linux/macOS) or `lib/qwen_native.dll` (Windows): C++17 native hook and IPC module loaded by Lua via `require("qwen_native")`.
- `lib/libqwen_mmap_guard.so`: POSIX C99 memory controller loaded via `LD_PRELOAD` by `llama-server`.
- `bin/kitsu-bin` / `bin/qwen-widget-bin`: Embedded launcher executable.

---

## 4. Running, Developing & Testing

### Launching the Application

1. **Direct launcher with full environment setup:**
   ```bash
   ./run.sh
   # or
   ./bin/kitsu
   ```
2. **Headless / syntax check for Lua modules:**
   ```bash
   LUA_PATH="/usr/share/lua/5.3/?.lua;/usr/share/lua/5.3/?/init.lua;lib/?.lua;?.lua;;" \
   LUA_CPATH="lib/?.so;/usr/lib/x86_64-linux-gnu/lua/5.3/?.so;;" \
   lua5.3 -e '
       local config = require("config")
       local utils = require("utils")
       local ac = require("avatar_customizer")
       print("All core Lua modules loaded successfully.")
   '
   ```

### Custom Avatar Subsystem (`lib/avatar_customizer.lua`)

The user can customize the widget image via either GUI or CLI:
- **From GUI:** Open Chat window $\to$ Click Gear Icon (Settings) $\to$ Tab 1 (General) $\to$ "Cambiar Imagen...".
- **From Terminal:**
  ```bash
  # Crop centered 1:1 and resize to 256x256 for the widget:
  ./bin/kitsu-avatar /path/to/any_image.jpg

  # Reset back to default stock artwork:
  ./bin/kitsu-avatar --reset
  ```

### Asset & Sprite Generation Pipeline

If the master source artwork (`assets/avatar_source.jpg`) is updated, regenerate all 7 state sprites and UI icons with:
```bash
python3 scripts/generate_sprites.py
```
This script automatically:
1. Strips EXIF metadata.
2. Centers the character crop.
3. Applies state-specific color grading, obsidian gradients, and high-DPI supersampling.
4. Exports both `.png` and `.webp` versions to `assets/sprites/`.
5. Compiles clean geometric vector icons into `assets/icons/`.

---

## 5. Architectural Invariants for Autonomous Agents

When modifying this repository, agents **MUST** respect the following non-negotiable rules:

### A. The $\le 500\text{ MB}$ Memory Ceiling
- **Cairo Context Lifecycles:** Always balance `cr:save()` with `cr:restore()`. Do not leave clipping paths active.
- **Garbage Collection Cadence:** Invoke `collectgarbage("step", 100)` after closing dialogs, unloading models, or closing docked panels.
- **Heap Trimming:** Native memory is pruned via `malloc_trim(0)` through `qwen_native.trim_memory()`. Always trigger this when models or heavy buffers are destroyed.
- **Model Context:** Never increase `--ctx-size` in `bin/llama-server` beyond 768 tokens without verifying RSS consumption.

### B. The Zero-Emoji Invariant
- **Strict Rule:** Never insert Unicode emojis (e.g. 🤖, 💬, 🎵, ⚙️) into labels, UI buttons, notifications, or terminal logs.
- Use typographic headers (`CHAT AI`, `SISTEMA`, `MUSICA`, `CORREGIR`) and draw vector paths with Cairo via `lib/icons.lua`.

### C. Non-Blocking Event Loop
- GTK's main loop (`Gtk.main()`) must never be blocked by synchronous network calls, slow disk I/O, or blocking subshells.
- Use `GLib.timeout_add()`, `GLib.idle_add()`, or async socket/cURL patterns for background workloads.

### D. Security & Key Storage
- Secrets (OpenAI, Gemini, Anthropic keys) are stored strictly in `~/.config/qwen-widget/secrets.json` with file mode `0600`.
- Configuration settings (non-sensitive preferences) reside in `~/.config/qwen-widget/config.json`.
- Never commit user credentials or hardcode tokens in the source tree.

### E. Native C++ / POSIX Safety
- Ensure all pointer operations in `src/qwen_native.cpp` check for null D-Bus connections and valid X11 Display descriptors.
- Do not introduce external C++ dependencies beyond standard POSIX, X11/XFixes, and GLib/GIO.
