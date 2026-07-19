# Codex Pulse project rules

- Build a native macOS menu-bar utility with SwiftUI and Foundation only.
- Read quota data through the locally installed Codex app-server protocol. Never read, copy, log, or persist authentication secrets.
- Keep the application unsandboxed because it must launch the user's local Codex executable and let that executable use its existing login state.
- Keep one source of truth for quota state. Poll sequentially, cancel cleanly, and show explicit disconnected or unavailable states.
- Comments must be in English. Do not add dependencies or commit changes.
- Before reporting completion, generate the Xcode project, run tests, build the app, launch it, and inspect the real status-bar UI.
