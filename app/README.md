# UsageOwl

A macOS menu bar app that shows usage/quota for multiple AI coding subscriptions at a glance.
Built with SwiftUI `MenuBarExtra`, pure Swift stdlib + SwiftUI + AppKit + Foundation — **no
external dependencies, no Xcode project**.

## Features

- Per-provider `<glyph> <%>` items in the menu bar (monochrome, adapts to light/dark),
  with per-provider toggles in the popup's Menu Bar section
- Brand glyphs drawn in code (`Canvas`/`Path`) — no asset files
- Popup with one card per provider: plan badge, brand glyph next to the primary %,
  per-window progress bars with "Resets at/on …" timestamps, error states with guidance
- Threshold notifications at 25 / 50 / 75 / 90 % per quota window (re-armed when the
  window resets)
- Auto-refresh every 30 s / 1 min / 5 min (configurable), manual "Refresh now", and
  refresh-on-open
- Launch at login (SMAppService)
- No telemetry. Credentials are read locally from the CLI tools' own stores; manual
  secrets are kept in the Keychain.

## Build & run

Requirements: macOS 14+, Apple Silicon, Swift toolchain (`swift`, `codesign`) on PATH.

```bash
cd app
./build_app.sh          # swift build -c release --arch arm64 + assembles dist/UsageOwl.app + ad-hoc codesign
open dist/UsageOwl.app
```

The app is a menu-bar-only agent (`LSUIElement` = true) — no Dock icon, no main window.
Click the gauge in the menu bar to open the popup; the gear opens Settings.

For development, `swift build` alone also works; note that notifications and launch-at-login
are silently disabled when running as a bare binary (they require a real app bundle).

## Provider credential sources

| Provider | Credential source | Endpoint | Notes |
|---|---|---|---|
| **Kimi** (Kimi Code CLI) | `~/.kimi-code/credentials/kimi-code.json` (auto) | `GET api.kimi.com/coding/v1/usages` | Weekly quota + rolling 5-hour rate window. On 401 refreshes via `auth.kimi.com/v1/oauth/token` and writes new tokens back to the CLI's file. |
| **Codex** (ChatGPT Plus/Pro) | `~/.codex/auth.json` (auto) | `GET chatgpt.com/backend-api/wham/usage` | Sends `ChatGPT-Account-Id` header. Shows primary/secondary rate windows + credit balance. |
| **Claude** (Claude Code) | Keychain item `Claude Code-credentials` (auto) | `GET api.anthropic.com/api/oauth/usage` with `anthropic-beta: oauth-2025-04-20` | On 401 refreshes via `console.anthropic.com/v1/oauth/token` and writes tokens back to the Keychain. First read triggers a macOS Keychain permission prompt — choose "Always Allow". |
| **Claude** (claude.ai) | One-time sign-in in Settings → persistent WebKit store (no cookie stored by us) | `GET claude.ai/api/organizations` → first org → `GET …/{orgId}/usage`, fetched **inside WebKit** | Adds windows the OAuth endpoint omits (e.g. Fable), and covers a missing/failing OAuth path. Must go through WebKit: Cloudflare binds `cf_clearance` to the TLS fingerprint, so a `URLSession` request with the same cookie gets a 403. |
| **Claude** (spend) | `~/.claude/projects/**/*.jsonl`, incl. `subagents/` (auto) | none — local files | Per-request token counts priced per model. Deduped on `(requestId, message.id)`; counting naively over-reports ~2.3x. |
| **GitHub Copilot** | Manual token in Settings (Keychain `UsageOwl-github-token`), else any `oauth_token` in `~/.config/github-copilot/apps.json` | `GET api.github.com/copilot_internal/user` | Uses VS Code/Copilot-Chat client headers. Shows premium interactions, chat, completions quotas. |
| **Moonshot** (platform) | API key in Settings (Keychain `UsageOwl-moonshot-key`) | `GET api.moonshot.ai/v1/users/me/balance` | Pay-as-you-go balance — displayed as text, not a gauge. |

All response parsing is deliberately tolerant (optional/alternate key names, 0–1 vs 0–100
scales, string-or-number fields) because these are undocumented endpoints that drift.

## Distribution

This app cannot be sandboxed: it reads CLI credential files from the user's home directory
(`~/.codex`, `~/.kimi-code`, `~/.config/github-copilot`) and other apps' Keychain items.
Therefore it must be distributed **outside the App Store**:

1. Sign with a Developer ID Application certificate:
   `codesign --force --deep --options runtime --sign "Developer ID Application: …" dist/UsageOwl.app`
2. Notarize: `xcrun notarytool submit … --wait` then `xcrun stapler staple dist/UsageOwl.app`
3. Ship as `.dmg` or `.zip`.

`build_app.sh` signs with a `Developer ID Application` identity when one exists in the
keychain (hardened runtime, staged outside the iCloud-synced Desktop so FileProvider
xattrs don't break signing), and falls back to ad-hoc (`--sign -`) otherwise. With
ad-hoc signing the signature changes on every rebuild, so macOS re-asks for Keychain
access after each build — use the Developer ID path to make "Always Allow" stick.

## Architecture

Single SwiftPM executable target (`swift-tools 5.10`, macOS 14+):

```
Sources/UsageOwl/
├── UsageOwlApp.swift          @main, MenuBarExtra (.window style), menu bar ring-gauge label
├── Models/
│   ├── UsageSnapshot.swift    provider-agnostic model (windows, balance, spend, error)
│   └── SpendSummary.swift     API-equivalent value vs money actually charged
├── Providers/
│   ├── AIProvider.swift       protocol + registry
│   ├── KimiProvider.swift     Kimi Code CLI (OAuth file, refresh-on-401)
│   ├── CodexProvider.swift    ChatGPT via Codex CLI auth.json
│   ├── ClaudeProvider.swift   Claude Code Keychain OAuth + claude.ai path + spend
│   ├── CopilotProvider.swift  GitHub Copilot copilot_internal API
│   └── MoonshotProvider.swift Moonshot platform balance
├── Services/
│   ├── HTTPClient.swift       shared URLSession wrapper
│   ├── KeychainHelper.swift   Security.framework save/read/delete/update
│   ├── ClaudeWebSession.swift persistent offscreen WKWebView as the claude.ai transport
│   ├── ClaudeCodeUsageReader.swift  incremental ~/.claude transcript scan -> day/model token rollups
│   ├── Pricing.swift          per-model list rates; cache rates derived (1.25x / 2x / 0.1x)
│   ├── BridgeServer.swift     127.0.0.1:18347 listener for the optional browser extension
│   ├── UsageStore.swift       @MainActor store: concurrent refresh, timer, settings, login item
│   ├── Notifier.swift         UNUserNotificationCenter threshold alerts (deduped per window)
│   ├── MenuBarImageRenderer.swift  composes the whole menu bar label as one template image
│   └── Format.swift           date/percent/countdown/currency helpers + tolerant JSON utils
└── Views/
    ├── MenuBarLabel.swift     menu bar glyph+% items (cached template NSImages)
    ├── MenuPopover.swift      popup: header, provider cards, spend rows, toggles, footer
    ├── ClaudeWebLoginView.swift  claude.ai sign-in sheet sharing the persistent store
    ├── ProviderGlyph.swift    code-drawn brand marks (Canvas/Path, no assets)
    └── SettingsView.swift     per-provider credential management, general settings
```

`swift run UsageOwl --dump-spend` prints the transcript-derived spend totals and
exits without starting the menu bar — the spend figure is derived from ~2,000
files, so it's worth being able to check it from a terminal.

## Roadmap

- Global hotkey to open the popup (⌘U)
- Persist notification dedupe state across restarts
- App icon

## License

MIT
