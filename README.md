# Codex Pulse

A native macOS menu-bar monitor for the remaining Codex allowance. It refreshes once per second and shows the primary weekly allowance directly in the status bar.

Current version: **0.1**

## Download

Download `CodexPulse-0.1-macOS.zip` from the [v0.1 release](https://github.com/jackotom/codex-plus-ed/releases/tag/v0.1), move the app to Applications, then open it. The build is not Apple-notarized, so macOS may require right-clicking the app and choosing **Open** on first launch.

## Use

Requirements: macOS 14 or later, with the official ChatGPT or Codex app installed and signed in.

The first launch shows a short welcome screen; after that, click the percentage in the status bar to view reset times and every available allowance window.

## Privacy

Codex Pulse asks the official local Codex process for quota data. It never reads, copies, logs, or stores your login credentials. This is an independent utility and is not affiliated with or endorsed by OpenAI.

## Build from source

```sh
xcodegen generate
xcodebuild -project CodexPulse.xcodeproj -scheme CodexPulse -configuration Release -derivedDataPath build/ReleaseDerivedData build
```

Requires Xcode 16 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

The app will be at `build/ReleaseDerivedData/Build/Products/Release/CodexPulse.app`.
