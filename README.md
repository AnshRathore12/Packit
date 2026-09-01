<div align="center">

# 📦 Packit

**A powerful, drop-in iOS network debugging toolkit for SwiftUI apps.**

Intercept, inspect, and debug network requests directly inside your app — monitor traffic, search transactions, decode JWTs, and export cURL commands, all without leaving your app.

[![Platform](https://img.shields.io/badge/Platform-iOS%2016%2B-lightgrey?style=flat-square)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-5-orange?style=flat-square&logo=swift&logoColor=white)](#requirements)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen?style=flat-square)](#installation)

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

---

## ✨ Features


---

## 📋 Requirements


---

## 📦 Installation

### Option A — Xcode App Project *(most common)*

If your app is a normal Xcode project (`.xcodeproj`), add Packit through Xcode's UI — no `Package.swift` file is involved:

1. 1Open your project in Xcode.
2. 2Go to **File → Add Package Dependencies…**
3. 3Enter the repository URL:
```
   https://github.com/AnshRathore12/Packit.git
```
4. 4Set the dependency rule to **Up to Next Major Version** from `1.0.0`.
5. 5Click **Add Package**.
6. 6Select **Packit** as the library to add to your target.

Xcode records this under your project's **Package Dependencies** tab and manages a `Package.resolved` file automatically.

### Option B — Swift Package

If your app (or library) is itself a Swift package with its own `Package.swift`, add Packit as a dependency there instead:

```swift
dependencies: [
    .package(
        url: "https://github.com/AnshRathore12/Packit.git",
        from: "1.0.0"
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
  <img src="https://github.com/user-attachments/assets/3c1e5609-2b38-4735-960d-6f24eaf982e5" width="180" alt="Packit screenshot 1" />
  <img src="https://github.com/user-attachments/assets/356ea199-9a0c-474d-a63e-d1b0a9de9676" width="180" alt="Packit screenshot 2" />
  <img src="https://github.com/user-attachments/assets/c02db45b-3629-4e95-abc7-df6a516b8ae5" width="180" alt="Packit screenshot 3" />
  <img src="https://github.com/user-attachments/assets/8e071b2b-179e-4e2e-b5d4-29d8ae9618bd" width="180" alt="Packit screenshot 4" />
  <img src="https://github.com/user-attachments/assets/72b56aa6-ad41-4724-8f2a-957fb2df3eb4" width="180" alt="Packit screenshot 5" />
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

1. 1Fork the repository.
2. 2Create a feature branch:
```bash
   git checkout -b feature/amazing-feature
```
3. 3Commit your changes:
```bash
   git commit -m "Add amazing feature"
```
4. 4Push to the branch:
```bash
   git push origin feature/amazing-feature
```
5. 5Open a Pull Request.

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

<div align="center">
  <sub>Built with SwiftUI, UIKit, and zero external dependencies.</sub>
</div>
