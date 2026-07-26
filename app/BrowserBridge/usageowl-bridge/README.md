# UsageOwl Bridge (browser extension) — optional

**You almost certainly don't need this.** UsageOwl now signs in to claude.ai
itself (Settings → **Connect claude.ai**) and reads the same data through an
embedded WebKit session, which covers the extra windows (like Fable) that the
OAuth endpoint omits.

This extension remains as a fallback for the one case the built-in flow can't
handle: an account whose Google sign-in Google refuses to complete inside an
embedded window. It uses your real browser, so nothing can block it. (The other
fallback is pasting a `sessionKey` under the same Settings row.)

## Install (Chrome / Edge / Arc / any Chromium)

1. Open `chrome://extensions`
2. Turn on **Developer mode** (top right)
3. Click **Load unpacked** and select this folder (`usageowl-bridge`)

That's it — no further step in the app. The extension watches for claude.ai tabs,
makes the same authenticated request the settings page makes, and posts the
resulting JSON to the app on `127.0.0.1:18347`. Your cookie never leaves the
browser, and nothing is sent anywhere except your own machine.

Note: the app's listener accepts any POST from localhost, so any local process
could feed it usage JSON. It only ever affects what the menu bar displays.

Uninstall anytime from `chrome://extensions`; syncing stops immediately.
