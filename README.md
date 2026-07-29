<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2016%2B-blue?style=for-the-badge" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5-orange?style=for-the-badge&logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/SPM-compatible-brightgreen?style=for-the-badge" alt="SPM">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey?style=for-the-badge" alt="License">
</p>

# 📦 Packit

**A powerful, drop-in iOS network debugging toolkit for SwiftUI apps.**

Packit lets you intercept, inspect, and debug every HTTP/HTTPS request in your app — with a single line of code. Drop it in, see everything, ship debug builds with superpowers.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🌐 **Network Inspector** | Intercept and inspect every HTTP/HTTPS request and response in real time |
| 🔍 **Smart Search** | Fuzzy search across all captured requests |
| 🔑 **JWT Decoder** | Decode and inspect JWT tokens found in headers or bodies |
| 📋 **cURL Export** | Copy any request as a ready-to-paste cURL command |
| 📎 **Copy JSON** | One-tap copy of request/response bodies |
| 🫧 **Floating Overlay** | Draggable debug button that works from any screen |

---

## 📋 Requirements

| Requirement | Minimum |
|-------------|---------|
| iOS | 16.0+ |
| Swift | 5 |
| Xcode | 15.0+ |
| Swift Package Manager | ✅ |

---

## 📦 Installation

### Swift Package Manager (SPM)

1. Open your project in Xcode.
2. Go to **File → Add Package Dependencies…**
3. Enter the repository URL:

   ```
   https://github.com/AnshumanRathore28/Packit.git
   ```

4. Set the dependency rule to **Up to Next Major Version** from `1.0.0`.
5. Click **Add Package**.
6. Select **Packit** as the library to add to your target.

#### Or, add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/AnshumanRathore28/Packit.git", from: "1.0.0")
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

Call `Packit.startIntercepting()` as early as possible in your app's lifecycle. This hooks into `URLSession` to capture all network traffic automatically.

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

### 2. Add the Floating Overlay (Recommended)

The easiest way to access Packit. Adds a draggable floating button to any view — tap it to open the full inspector.

```swift
struct ContentView: View {
    var body: some View {
        NavigationStack {
            // Your app content
            Text("Hello, World!")
        }
        .withNetworkInspectorOverlay()  // ← One line. That's it.
    }
}
```

### 3. Or Embed Directly

Use `PackitView` to embed the inspector into your own navigation:

```swift
NavigationLink("Debug Network") {
    PackitView()
}
```

---

## 🔧 Feature Guide

### 🌐 Network Inspector

Once `Packit.startIntercepting()` is called, every `URLSession` request (including `async/await`, Combine, Alamofire, and any library using `URLSession` under the hood) is automatically captured.

**What you can see for each request:**
- URL, method, status code, and timing
- Request and response headers
- Request and response bodies with a fully interactive JSON viewer
- One-tap copy of the entire JSON body
- cURL command generation
- JWT decoding for Authorization headers

**Search:**
- **Fuzzy search** — find requests by partial URL, method, or status code

---

## 🏗️ Architecture

Packit is designed as a single, self-contained SwiftUI module with no external dependencies.

```
Sources/Packit/
├── AppWide/                    # Top-level views
└── NetworkInspector/           # Network inspection UI & logic
    ├── Networking/             # Core: URLProtocol, stores, models, search engines
    ├── UI/                     # Shared UI components
    ├── Packit.swift            # Public entry point (Packit.startIntercepting)
    ├── NetworkInspectorView.swift
    ├── TransactionDetailsView.swift
    ├── JSONViewer.swift
    └── ...
```

---

## 🛡️ Automatic Release Safety

**Packit automatically disables itself in release builds.** You don't need to wrap anything in `#if DEBUG` — the SDK handles it for you.

Every public API uses compile-time `#if DEBUG` guards internally, so in a release build:

| API | Debug Build | Release Build |
|-----|------------|---------------|
| `Packit.startIntercepting()` | Registers URLProtocol, swizzles URLSession | **Complete no-op** |
| `.withNetworkInspectorOverlay()` | Shows draggable floating button | **Passthrough** (returns your view unmodified) |
| `PackitView()` | Renders Network Inspector | **EmptyView** |

This means your code can simply be:

```swift
@main
struct MyApp: App {
    init() {
        Packit.startIntercepting()  // ← Safe. No-op in release.
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .withNetworkInspectorOverlay()  // ← Safe. Passthrough in release.
        }
    }
}
```

### What this guarantees in production:

- ✅ **Zero swizzling** — no method_exchangeImplementations calls
- ✅ **Zero URLProtocol registration** — no network interception overhead
- ✅ **Zero UI** — no debug views, buttons, or sheets
- ✅ **App Store safe** — no debug code paths in the binary
- ✅ **No code changes needed** — just flip to Release in Xcode

### Further Optimization: Exclude from Release Binary (Optional)

To completely strip Packit from the release binary for maximum size savings, conditionalize the SPM dependency in your `Package.swift`:

```swift
// In your app's Package.swift
let package = Package(
    name: "MyApp",
    dependencies: [
        .package(url: "https://github.com/AnshumanRathore28/Packit.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: [
                .product(name: "Packit", package: "Packit", condition: .when(platforms: [.iOS]))
            ]
        )
    ]
)
```

---

## 🤝 Contributing

Contributions are welcome! Here's how:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Setup

```bash
git clone https://github.com/AnshumanRathore28/Packit.git
cd Packit
open Package.swift  # Opens in Xcode
```

Build and run tests:

```bash
swift build
swift test
```

---

## 📄 License

Packit is released under the **MIT License**. See [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

Built with ❤️ using SwiftUI and zero external dependencies.

---

<p align="center">
  <b>If Packit helped you debug faster, consider giving it a ⭐️</b>
</p>
