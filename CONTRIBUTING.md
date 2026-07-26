# Contributing to UsageOwl

Thanks for helping out. UsageOwl is MIT-licensed and community-driven.

## Ground rules

- **Privacy is the product.** No analytics, no telemetry, no outbound calls except the providers' own quota endpoints. PRs that violate this will not be merged.
- Keep it small and native — no new dependencies without a very good reason.
- Never commit credentials, tokens, or cookies. Test with your own accounts only.

## Adding a provider (most wanted!)

1. Read [docs/PROVIDERS.md](docs/PROVIDERS.md) for how existing providers work.
2. Create `app/Sources/UsageOwl/Providers/YourProvider.swift` conforming to `AIProvider`:
   - `isAvailable()` — detect local credentials without throwing
   - `fetchUsage()` — return a `UsageSnapshot` with windows, reset dates, and a plan label
3. Register it in `AIProvider.swift`'s `all` array.
4. Add a Settings row if the provider needs a manually pasted token.
5. Update the provider tables in `README.md` and `docs/PROVIDERS.md`, and the website's Providers section.

Parsing must be tolerant: providers change response shapes without notice. Use optionals, alternate key names, and sane fallbacks.

## Development

```bash
cd app && swift build            # debug build
./build_app.sh                   # release .app bundle in dist/
```

Swift 5.10, macOS 14 SDK, zero external packages. Match the existing code style (small files, one type per file, `// MARK:` sections where useful).

## Pull requests

- One concern per PR. Describe what you tested and on which macOS version.
- Website changes: verify `npm run build` passes in `website/`.
- App changes: verify `swift build -c release` and `./build_app.sh` pass.

## Code of conduct

Be kind, be specific, assume good intent. That's it.
