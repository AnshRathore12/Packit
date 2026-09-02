<div align="center">

# 📦 Packit

**A powerful, drop-in iOS network debugging toolkit for SwiftUI apps.**

Intercept, inspect, and debug network requests directly inside your app — monitor traffic, search transactions, decode JWTs, and export cURL commands, all without leaving your app.

[![Platform](https://img.shields.io/badge/Platform-iOS%2016%2B-lightgrey?style=flat-square)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-5-orange?style=flat-square&logo=swift&logoColor=white)](#requirements)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen?style=flat-square)](#installation)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)

</div>

---

## Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Feature Guide](#-feature-guide)
- [Architecture](#-architecture)
- [Release Safety](#-release-safety)
- [Contributing](#-contributing)
- [License](#-license)

---

## ✨ Features

| Feature | Description |
|---|---|
| 🌐 **Network Inspector** | Intercept and inspect `URLSession` requests and responses in real time |
| 🔍 **Smart Search** | Quickly search across captured network transactions |
| 🔑 **JWT Decoder** | Decode and inspect JWT tokens found in headers or request/response bodies |
| 📋 **cURL Export** | Copy any captured request as a ready-to-paste cURL command |
| 📎 **Copy JSON** | One-tap copy of request and response bodies |
| 🫧 **Floating Overlay** | Draggable debug button accessible from any screen |

---

## 📋 Requirements

| Requirement | Minimum |
|---|---|
| iOS | 16.0+ |
| Swift | 5 |
| Xcode | 15.0+ |
| Swift Package Manager | ✅ |

---

## 📦 Installation

### Option A — Xcode App Project *(most common)*

If your app is a normal Xcode project (`.xcodeproj`), add Packit through Xcode's UI — no `Package.swift` file is involved:

1. Open your project in Xcode.
2. Go to **File → Add Package Dependencies…**
3. Enter the repository URL:
   ```
   https://github.com/AnshRathore12/Packit.git
   ```
4. Set the dependency rule to **Up to Next Major Version** from `1.0.4`.
5. Click **Add Package**.
6. Select **Packit** as the library to add to your target.

Xcode records this under your project's **Package Dependencies** tab and manages a `Package.resolved` file automatically.

### Option B — Swift Package

If your app (or library) is itself a Swift package with its own `Package.swift`, add Packit as a dependency there instead:

```swift
dependencies: [
    .package(
        url: "https://github.com/AnshRathore12/Packit.git",
        from: "1.0.4"
    )
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["Packit"]
)
```

---

## 🚀 Quick Start

### 1. Start Network Interception

Call `Packit.startIntercepting()` as early as possible in your app's lifecycle. Packit uses `URLProtocol` to capture supported `URLSession` network traffic automatically.

```swift
import SwiftUI
import Packit

@main
struct MyApp: App {
    init() {
        Packit.startIntercepting()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Add the Floating Overlay *(recommended)*

The easiest way to access Packit. Add the draggable floating button to your root view and tap it to open the Network Inspector.

```swift
struct ContentView: View {
    var body: some View {
        NavigationStack {
            // Your app content
            Text("Hello, World!")
        }
        .withNetworkInspectorOverlay()
    }
}
```

### 3. Or Embed Directly

Use `PackitView` to embed the Network Inspector directly into your own navigation flow:

```swift
NavigationLink("Debug Network") {
    PackitView()
}
```

---

## 🔧 Feature Guide

<div align="center">
<img width="180"  alt="Simulator Screenshot - iPhone 16 - 2026-09-02 at 00 13 27" src="https://github.com/user-attachments/assets/77553af7-d0e7-40b5-ab67-6723ad432cda" />
<img width="180"  alt="Simulator Screenshot - iPhone 16 - 2026-09-02 at 00 13 34" src="https://github.com/user-attachments/assets/2b857044-2af1-4c61-996a-728df5d66c00" />
<img width="180"  alt="Simulator Screenshot - iPhone 16 - 2026-09-02 at 00 13 54" src="https://github.com/user-attachments/assets/6da131e6-9b7e-400f-8ce8-1d21af2490ab" />
<img width="180"  alt="Simulator Screenshot - iPhone 16 - 2026-09-02 at 01 39 10" src="https://github.com/user-attachments/assets/1574d488-e432-464a-b0ec-33635f3b97c1" />
<img width="180"  alt="Simulator Screenshot - iPhone 16 - 2026-09-02 at 00 14 07" src="https://github.com/user-attachments/assets/5d1fedb0-4a23-4c6f-ab1a-69be98f3a07f" />
</div>

### Network Inspector

Once `Packit.startIntercepting()` is called, Packit captures supported `URLSession` traffic, including requests made through APIs such as `async/await` and Combine when they use `URLSession` underneath.

**What you can see for each request:**

- URL, HTTP method, status code, and timing
- Request and response headers
- Request and response bodies
- Interactive JSON viewer
- One-tap copy of JSON payloads
- cURL command generation
- JWT decoding for Authorization headers

---

## 🏗️ Architecture

Packit is designed as a single, self-contained SwiftUI module with no external dependencies.

```
Sources/Packit/
├── AppWide/                    # Top-level views
└── NetworkInspector/           # Network inspection UI & logic
    ├── Networking/             # Core: URLProtocol, stores, models, search engines
    ├── UI/                     # Shared UI components
    ├── Packit.swift             # Public entry point
    ├── NetworkInspectorView.swift
    ├── TransactionDetailsView.swift
    ├── JSONViewer.swift
    └── ...
```

---

## 🛡️ Release Safety

Packit automatically disables itself in release builds. You don't need to wrap Packit APIs in `#if DEBUG` — the SDK handles this internally. Every public API uses compile-time `#if DEBUG` guards, so in a release build:

| API | Debug Build | Release Build |
|---|---|---|
| `Packit.startIntercepting()` | Registers `URLProtocol`, swizzles `URLSession` | Complete no-op |
| `.withNetworkInspectorOverlay()` | Shows draggable floating button | Passthrough |
| `PackitView()` | Renders Network Inspector | `EmptyView` |

This means your app code can remain unchanged between Debug and Release builds:

```swift
@main
struct MyApp: App {
    init() {
        Packit.startIntercepting()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .withNetworkInspectorOverlay()
        }
    }
}
```

**What this guarantees in production:**

- ✅ Zero swizzling — no `method_exchangeImplementations` calls
- ✅ Zero `URLProtocol` registration — no network interception overhead
- ✅ Zero UI — no debug views, buttons, or sheets
- ✅ App Store safe — debug functionality is disabled in Release builds
- ✅ No code changes needed — simply switch to Release in Xcode

---

## 🤝 Contributing

Contributions are welcome! Here's how:

1. Fork the repository.
2. Create a feature branch:
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. Commit your changes:
   ```bash
   git commit -m "Add amazing feature"
   ```
4. Push to the branch:
   ```bash
   git push origin feature/amazing-feature
   ```
5. Open a Pull Request.

### Development Setup

```bash
git clone https://github.com/AnshRathore12/Packit.git
cd Packit
open Package.swift
```

Build and run tests:

```bash
swift build
swift test
```

---

## 📄 License

Packit is available under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">
  <sub>Built with SwiftUI, UIKit, and zero external dependencies.</sub>
</div>
