# UsageOwl provider reference

How each provider integration works. All endpoints are the providers' own; UsageOwl only reads quota/usage data, on-device, with the user's own credentials.

> These endpoints are mostly undocumented and can change without notice. Parsers are deliberately tolerant — keep them that way.

## Kimi (Kimi Code CLI)

- **Credentials**: `~/.kimi-code/credentials/kimi-code.json` → `{ access_token, refresh_token, expires_at, ... }`
- **Usage**: `GET https://api.kimi.com/coding/v1/usages` — `Authorization: Bearer <access_token>`
- **Refresh** (on 401): `POST https://auth.kimi.com/v1/oauth/token` — `{ grant_type: "refresh_token", refresh_token }`
- **Response** (verified 2026-07):

```json
{
  "user": { "membership": { "level": "LEVEL_INTERMEDIATE" } },
  "usage": { "limit": "100", "used": "3", "remaining": "97", "resetTime": "2026-07-24T22:53:35Z" },
  "limits": [{ "window": { "duration": 300, "timeUnit": "TIME_UNIT_MINUTE" },
               "detail": { "limit": "100", "used": "13", "remaining": "87", "resetTime": "..." } }],
  "totalQuota": { "limit": "100", "remaining": "99" }
}
```

`usage` = weekly quota; `limits[0]` = rolling 5-hour rate window. Numbers arrive as strings.

## Codex (ChatGPT Plus/Pro via Codex CLI)

- **Credentials**: `~/.codex/auth.json` → `{ tokens: { access_token, account_id, refresh_token, ... } }`
- **Usage**: `GET https://chatgpt.com/backend-api/wham/usage` — `Authorization: Bearer <access_token>`, `ChatGPT-Account-Id: <account_id>`
- **Response** (verified 2026-07): `plan_type` (`"plus"`, `"pro"`, ...), `rate_limit.primary_window { used_percent, limit_window_seconds, reset_after_seconds, reset_at }`, `rate_limit.secondary_window` (nullable), `credits.balance`.

## Claude (Claude Code)

- **Credentials**: macOS Keychain item, service `Claude Code-credentials` → `{ claudeAiOauth: { accessToken, refreshToken, expiresAt, subscriptionType, rateLimitTier } }`. First access shows a macOS permission prompt (the item is owned by Claude Code).
- **Usage**: `GET https://api.anthropic.com/api/oauth/usage` — `Authorization: Bearer <accessToken>`, `anthropic-beta: oauth-2025-04-20`
- **Refresh** (on 401): `POST https://console.anthropic.com/v1/oauth/token` — `{ grant_type: "refresh_token", refresh_token, client_id: "9d1c250a-e61b-44d9-88ed-5944d1962f5e" }`; updated tokens are written back to the Keychain.
- **claude.ai path** (extra windows, e.g. Fable): `GET https://claude.ai/api/organizations` → `GET https://claude.ai/api/organizations/{orgId}/usage`. Both run **inside WebKit** via `ClaudeWebSession` — `fetch(..., {credentials: 'include'})` in a persistent offscreen `WKWebView`. This is not a stylistic choice: `cf_clearance` is bound to the client's TLS fingerprint, so the same request from `URLSession` carrying the same cookie is answered by Cloudflare with a 403 regardless of the `User-Agent` it presents. The session cookie is never read out of WebKit, and never stored in the Keychain.
- **Priority**: claude.ai is tried **first** when connected. It returns strictly more than the OAuth endpoint (all windows including model-scoped ones, plus the real extra-usage charge) and isn't subject to the OAuth usage endpoint's rate limit, which answers 429 under repeated refreshes. OAuth is the fallback. The plan label is read from the Keychain item directly, so the claude.ai path doesn't spend a request on it.
- **Windows** (claude.ai response, verified 2026-07): a `limits` array supersedes the individual keys —
  ```json
  "limits": [
    {"kind":"session",       "group":"session","percent":4,"resets_at":"…","scope":null,"is_active":true},
    {"kind":"weekly_all",    "group":"weekly", "percent":2,"resets_at":"…","scope":null,"is_active":false},
    {"kind":"weekly_scoped", "group":"weekly", "percent":0,"resets_at":null,
     "scope":{"model":{"id":null,"display_name":"Fable"},"surface":null},"is_active":false}
  ]
  ```
  **The model-scoped entry is the only place Fable appears.** `seven_day_opus`, `seven_day_sonnet`, `seven_day_cowork`, `seven_day_omelette`, `tangelo`, `iguana_necktie`, `omelette_promotional`, `nimbus_quill`, `cinder_cove`, `amber_ladder` are all `null`, so scanning top-level keys for a model name cannot find it. `resets_at` is nullable on scoped windows.
  Legacy fallback (still what the OAuth endpoint returns): top-level `five_hour` / `seven_day` objects with `utilization` + `resets_at`, and alternate key names.
- **Percent scale — do not guess it.** Every observed reading is 0–100: `percent: 4` and `utilization: 4.0` both render as "4% used" in claude.ai's own UI. The parser once treated `value <= 1.0` as a 0–1 fraction and rescaled it, which silently turned a genuine **1% into 100%** — a full red bar plus a false 90%-of-quota notification. `ClaudeProvider.asPercent` now rescales only when the value is *strictly* between 0 and 1, so 1.0 means 1%. That errs toward under-reporting rather than crying wolf.
- **Extra usage** (real money, claude.ai only, verified 2026-07): two shapes for the same figures —
  ```json
  "spend": {"used":{"amount_minor":29341,"currency":"USD","exponent":2},
            "limit":{"amount_minor":33000,"currency":"USD","exponent":2},
            "percent":89,"severity":"warning","enabled":true}
  "extra_usage": {"is_enabled":true,"monthly_limit":33000,"used_credits":29341.0,
                  "utilization":88.91,"currency":"USD","decimal_places":2}
  ```
  `spend` is preferred; `extra_usage` is the credit-unit fallback. Divide by `10^exponent` (or `10^decimal_places`). Absent means "not reported" and must not render as $0.00. Threshold notifications fire at 50/75/90% of the cap and re-arm each billing month.
- **Spend**: neither usage endpoint returns tokens — both report window *utilisation* — so no dollar figure can be derived from either. Spend comes from `~/.claude/projects/**/*.jsonl` (including `<session>/subagents/`), priced per model. Records must be deduped on `(requestId, message.id)`: one API response is written once per content block with the same `usage` object, which over-reports by ~2.3x if counted naively. Cache reads are ~96% of all tokens, so the 0.1x cache-read rate dominates the total.

## GitHub Copilot

- **Credentials**: manual GitHub token (Keychain `UsageOwl-github-token`), or any `oauth_token` found in `~/.config/github-copilot/apps.json`.
- **Usage**: `GET https://api.github.com/copilot_internal/user` with VS Code-flavoured headers (`Editor-Version`, `Editor-Plugin-Version`, `User-Agent: GitHubCopilotChat/...`, `X-Github-Api-Version`).
- **Response**: `copilot_plan`, `quota_reset_date` (`YYYY-MM-DD`), `quota_snapshots.premium_interactions { entitlement, remaining, unlimited }`, `quota_snapshots.chat`. `unlimited: true` snapshots are shown as such, not gauges.

## Moonshot / Kimi Platform (pay-as-you-go)

- **Credentials**: API key from platform.kimi.com (Keychain `UsageOwl-moonshot-key`).
- **Balance**: `GET https://api.moonshot.ai/v1/users/me/balance` — Bearer key.
- Displayed as a balance line, not a percentage gauge.

## Adding a provider

See [CONTRIBUTING.md](../CONTRIBUTING.md#adding-a-provider-most-wanted). Candidates: Cursor, Gemini/Antigravity (local history files), Zed, Windsurf, OpenRouter (`GET /api/v1/auth/key` credit info), DeepSeek (`GET https://api.deepseek.com/user/balance`).
