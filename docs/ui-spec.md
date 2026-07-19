# Codex Pulse UI / interaction specification

## Completion contract

The UI is accepted when it provides a native macOS menu-bar label, a compact `MenuBarExtra` window, and clearly distinguishable normal, first-load, stale/error, unavailable, and exhausted states. It must remain readable in light/dark mode, with keyboard and VoiceOver, and with real Chinese content at 100% and 200% interface scale.

## Platform shape

- Use `MenuBarExtra` with `.menuBarExtraStyle(.window)`. Apple defines this as a popover-like window intended for data-rich menu-bar extras; do not reproduce a custom title bar, arrow, shadow, or rounded outer shell.
- Target macOS 14. The panel is a single level: no navigation stack, tab bar, sidebar, sheet, or settings screen in v1.
- Root content width: **336 pt**. Outer padding: **16 pt** horizontal, **14 pt** top, **12 pt** bottom.
- Natural panel height: **260–520 pt**. The header, primary quota, warning, and footer stay visible. Only the quota-detail region scrolls when content would exceed 520 pt.
- Do not force a translucent custom background over the window. Use the native window background; inner cards may use a system material or semantic control background plus a subtle separator.
- The app has no Dock icon, so the panel must expose both **Refresh** and **Quit Codex Pulse** actions.

References: [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra), [window menu-bar style](https://developer.apple.com/documentation/swiftui/menubarextrastyle/window), [macOS design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/).

## First-launch welcome window

Show one welcome window only on the first launch. Its single job is to explain the status-bar utility and let the user start using it. It is not a setup wizard: no account form, permission prompt, settings, page indicator, carousel, secondary action, or later onboarding screen.

### Window and visual direction

- Default window size: **520 × 560 pt**, centered on the active screen and not resizable. Keep all content on one screen at the default text size.
- Use the native window background and system title-bar behavior. Do not add a custom outer shell, full-window gradient, glow, blur, illustration, or drop shadow.
- The new app icon is the only hero visual: render it at **96 × 96 pt**, centered, without an extra plate or decorative backdrop.
- Brand accents follow the actual icon: deep blue `#071B4C` and electric blue `#18DDF7`. Use deep blue for quiet glyph containers and electric blue for small glyph accents, never for body text on a light background. Keep the primary action on the accessible system `accentColor`; in dark mode and Increase Contrast, prefer semantic variants rather than forcing the exact hex values.
- Everything else stays consistent with the status-bar panel: San Francisco, semantic text colors, 12–14 pt continuous corner radii, subtle system separators, native focus rings, and no decorative shadows.
- Outer padding: **44 pt** horizontal, **32 pt** top, **26 pt** bottom. Use one centered column; maximum text width is **400 pt**.

### Content hierarchy and exact copy

Top to bottom:

1. App icon, then a quiet 12 pt semibold brand label: `Codex Pulse`.
2. Main title, 28 pt semibold: `随时掌握 Codex 额度`.
3. Supporting copy, 13 pt regular, secondary color, maximum two lines: `剩余额度、重置时间和连接状态，都在菜单栏里一眼看清。`
4. Three value rows. Each row uses one 30 × 30 pt rounded icon container, a 13 pt semibold title, and one 11 pt secondary line:
   - `menubar.rectangle` — `状态栏实时显示` — `不用打开 Codex，也能看到本周剩余额度。`
   - `arrow.clockwise` — `秒级自动更新` — `后台顺序刷新，数据变化及时可见。`
   - `calendar.badge.clock` — `重置时间清楚可见` — `5 小时与 7 天额度分别展示，不会混淆。`
5. One quiet privacy row with `lock.shield.fill`, 12 pt body text, and a 12 pt corner radius: `只通过本机 Codex 读取额度，不读取、不保存登录凭据。`
6. One primary button, **280 × 44 pt**, 12 pt corner radius: `开始使用`.

Use 8 pt between the icon and brand label, 6–8 pt within text groups, 12 pt between value rows, 18–20 pt between major groups, and at least 24 pt before the primary button. The three value rows are not separate cards; keep them as quiet aligned rows so the icon remains the visual focus.

### Interaction and lifecycle

- The status-bar item and quota monitor may start immediately; the welcome window must not pause or own the monitoring lifecycle.
- `开始使用` is the default button and responds to Return. It records welcome completion, closes the window, and leaves Codex Pulse running in the status bar.
- Closing the window with the standard close control leaves the app running but does not record completion, so the welcome window appears again on the next app launch.
- Do not open the status-bar panel automatically after dismissal, request login details, or redirect to Codex. The menu-bar item is already visible and is the next natural interaction.
- Persist only the local completion flag. Do not attach account, quota, or authentication data to it.

### Accessibility and acceptance

- VoiceOver order follows the visual order: icon/brand, title, summary, three value rows, privacy statement, then `开始使用`. Mark purely decorative icon containers as hidden while giving each value row one combined label.
- The button needs the native hover, pressed, disabled, and keyboard-focus treatments. No entrance animation is required; Reduce Motion therefore needs no alternate presentation.
- At 200% interface scale, allow the content area to scroll vertically rather than clipping text or shrinking fonts. The default 100% layout must not scroll.
- Verify light mode, dark mode, Increase Contrast, keyboard-only use, VoiceOver reading order, standard window close behavior, and the one-time completion rule.

## Information hierarchy

Top to bottom:

1. Header: product name, account-plan badge, refresh action.
2. Stale/error banner when required.
3. Primary weekly quota card: the one value represented in the menu bar.
4. `额度明细`: every returned limit bucket and its primary/secondary windows.
5. Footer: connection/last-refresh status and quit action.

The primary weekly quota is the only hero. Other buckets must not compete with it through equally large rings, large type, or saturated color.

## Metrics and type

| Element | Specification |
| --- | --- |
| Header | 28 pt high; product name 13 pt semibold; plan badge 11 pt medium |
| Section title | 12 pt semibold, secondary color |
| Primary card | 104 pt minimum height, 14 pt corner radius, 14 pt inner padding |
| Primary ring | 82 pt diameter, 8 pt stroke, round line caps |
| Ring value | 22 pt semibold, rounded, monospaced digits |
| Body | 13 pt regular |
| Bucket value | 13 pt semibold, monospaced digits |
| Metadata | 11 pt regular, secondary color |
| Bucket card | 12 pt corner radius, 12 pt inner padding, 8 pt between window rows |
| Progress bar | 6 pt high, fully rounded |
| Icon button | 28 × 28 pt target; 13 pt SF Symbol |
| Major spacing | 12 pt between sections |
| Minor spacing | 6–8 pt within a component |

Use San Francisco through SwiftUI system fonts. No bundled fonts, gradients, neon glow, decorative blur, or drop shadows. Never use text smaller than 10 pt.

## Color and quota semantics

Use system semantic colors so light mode, dark mode, Increase Contrast, and tint changes remain valid.

| Remaining | Accent | Required non-color cue |
| --- | --- | --- |
| 51–100% | `accentColor` | Numeric percentage |
| 21–50% | system orange | Numeric percentage |
| 1–20% | system red | `exclamationmark.circle.fill` and “额度偏低” |
| 0% | system red | `xmark.circle.fill` and “额度已用完” |
| Loading/unavailable | secondary | Progress or unavailable symbol plus text |

The ring track uses a low-emphasis semantic fill; detail bars use the same threshold color as their numeric value. Do not tint the whole panel or card. Connection state also uses icon plus text, never a colored dot alone.

## Menu-bar label

Keep the status item stable and short; the value refers only to the primary weekly remaining percentage.

| State | Visible label | Accessibility label |
| --- | --- | --- |
| Healthy | `72%` | `Codex 本周额度剩余 72%` |
| First load | `…` | `Codex 额度正在加载` |
| Stale snapshot | `72% !` | `Codex 本周额度剩余 72%，数据已过期` |
| No usable snapshot | `--` | `Codex 额度暂不可用` |
| Exhausted | `0%` | `Codex 本周额度已用完` |

- Pair the text with one monochrome template SF Symbol; the symbol may change for unavailable/error, but the healthy symbol must stay visually quiet.
- Do not show “剩余”、plan name, reset time, countdown seconds, or last-refresh time in the menu bar.
- Do not animate the status item every second. Update it only when the displayed percentage or connection state changes.
- Reserve enough value width for `100%` so the menu bar does not visibly jump between one, two, and three digits.

## Header and primary card

Header layout:

- Left: quiet app glyph and `Codex Pulse`.
- Next: neutral plan badge such as `Plus`; hide the badge when the plan is absent instead of showing a placeholder.
- Right: borderless refresh button with `arrow.clockwise`, tooltip `立即刷新`, and a disabled state while a request is in flight.

Primary card layout:

- Left column: `本周额度`, reset text, and optional `额外额度 ×3` metadata.
- Right: 82 pt ring with the remaining percentage centered inside.
- Reset copy: `今天 18:40 重置`, `明天 09:15 重置`, or `7月22日 09:15 重置`. Do not show seconds or a raw timestamp.
- If reset time is missing, show `重置时间未知`; never invent a reset time.
- A manual refresh with an existing snapshot keeps the card visible. Only the refresh control indicates work; do not replace the content with a spinner.

## Quota details

- Section title: `额度明细`.
- Show every returned limit bucket. Do not depend on dictionary order: put the bucket containing the primary weekly window first, then sort remaining display names. Within a bucket, show the shorter-duration window before the longer-duration window.
- Each bucket is one quiet card. The bucket title is one line. Each window is a compact two-line row:
  - First line: window label on the left (`5 小时额度`, `7 天额度`) and `82% 剩余` on the right.
  - Second line: progress bar and reset text.
- Separate primary and secondary windows with a system divider; do not create a nested card for each window.
- Unknown bucket names are allowed: show the backend display name, use tail truncation after 12 Chinese characters / about 22 Latin characters, and expose the full name in a tooltip and accessibility label.
- Empty buckets are omitted. If no bucket has a usable window, use the unavailable state instead of showing an empty `额度明细` section.

## States

### Healthy

Show all hierarchy. Footer status is `checkmark.circle.fill  实时` while the latest successful sample is no more than 2 seconds old. The percentage has no per-second animation.

### First load

Keep a stable minimum panel height of 260 pt. Center a native `ProgressView` with `正在连接 Codex…` and secondary text `首次读取可能需要几秒`. Do not use shimmer placeholders or a fake percentage. Menu bar shows `…`.

### Stale snapshot / reconnecting

Keep the last verified snapshot visible and add a compact orange banner above the primary card:

`exclamationmark.triangle.fill  数据已过期，正在重新连接`

Show the real last successful refresh time in the footer. Menu bar keeps the verified value and appends `!`. Never present stale data as `实时`.

### No connection or unavailable

With no usable snapshot, replace quota content with a centered state card:

- `wifi.slash` for a connection/process failure; title `无法连接 Codex`.
- `questionmark.circle` when the process responds but has no supported quota data; title `额度暂不可用`.
- One user-facing explanation, maximum two lines. Do not expose protocol text, paths, or raw error dumps.
- Primary button: `重试`. Secondary action remains `退出 Codex Pulse` in the footer.

Menu bar shows `--`; no guessed or cached percentage is substituted.

### Exhausted

Keep the regular dashboard structure. The ring is empty and red, centered value is `0%`, and the left title becomes `本周额度已用完`. Make the reset time the next strongest text. No pulsing, modal alert, notification, or full-panel red treatment.

## Interaction

- Single click on the status item toggles the native window. Clicking elsewhere dismisses it through standard `MenuBarExtra` behavior.
- Refresh is idempotent: one click starts one request; repeated clicks while loading do nothing.
- The one-second background refresh must not steal keyboard focus, reset scroll position, flash the panel, or announce unchanged values.
- The detail list preserves its current scroll position while the panel remains open.
- `Esc` follows native panel dismissal. Tab order is refresh, retry when present, detail scroll content if needed, then quit.
- Use native hover, focus ring, disabled, and pressed states. Do not create custom pointer gestures for standard buttons.

## Accessibility

- Support light/dark mode, Increase Contrast, Reduce Transparency, and Reduce Motion. When Reduce Motion is active, remove ring interpolation and refresh rotation; the native progress indicator may remain.
- Minimum text contrast: 4.5:1 for normal text and 3:1 for bold/large text. Prefer system colors and materials.
- Ring and progress bars each need a text label and accessibility value, for example `本周额度，剩余 72%，周一 09:15 重置`; do not make VoiceOver infer meaning from the drawing.
- Combine each two-line window row into one VoiceOver element. Hide decorative symbols and dividers from accessibility.
- Announce only meaningful state transitions: first successful connection, disconnected, and exhausted. Do not announce every one-second refresh.
- Critical text must remain readable at 200% interface scale. Allow the primary card and rows to grow vertically rather than clipping. Numeric values may use a minimum scale factor of 0.8 but never truncate.
- All icon-only buttons require a spoken label and tooltip. Keyboard focus must be visible.

Reference: [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility/).

## Chinese copy and length limits

Use these exact short labels unless the data changes their value:

- `本周额度`
- `额度明细`
- `82% 剩余`
- `额外额度 ×3`
- `实时`
- `数据已过期，正在重新连接`
- `无法连接 Codex`
- `额度暂不可用`
- `本周额度已用完`
- `立即刷新`
- `重试`
- `退出 Codex Pulse`

Panel titles should remain within 12 Chinese characters. Helper/error copy is limited to two lines and about 36 Chinese characters. Percentage values are always rounded whole numbers in the UI (`0%`–`100%`); avoid decimals because they add churn without actionable precision.

## Visual acceptance checklist

- Inspect the real status item and open panel, not only an Xcode preview.
- Check healthy values at `100%`, `72%`, `20%`, `1%`, and `0%` for color thresholds and number-width stability.
- Check first load, stale snapshot, disconnected, unavailable, and exhausted using deterministic fixtures.
- Check one bucket, many buckets with scrolling, a bucket with primary and secondary windows, a missing reset time, and a long unknown bucket name.
- Check light mode, dark mode, Increase Contrast, Reduce Transparency, Reduce Motion, 200% interface scale, keyboard-only navigation, and VoiceOver reading order.
- Leave the panel open for at least 10 seconds and confirm polling causes no flicker, focus loss, scroll jumps, repeated speech, or overlapping requests.
