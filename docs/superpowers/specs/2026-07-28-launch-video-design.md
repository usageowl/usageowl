# UsageOwl launch video — design

**Date:** 2026-07-28
**Status:** approved, implemented

## Purpose

A 25-second silent video for the v1.0.0 launch, shown on X, Product Hunt, and
embedded on usageowl.com. Its job is to make a stranger understand the problem
within three seconds and know where to get the fix by the end.

## Decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Aspect ratio | 1920×1080, 16:9 | Widest reuse from one render: site embed, PH gallery, README, X timeline. Vertical would gain phone feeds but lose every other surface. |
| Length | 18.5s @ 30fps (555 frames) | Recut from 25s. The video-ad-generator skill's PAS timing puts the problem beat at 2-3s; the first cut spent 6.5s there. Every scene was tightened. |
| Audio | None | No licensed track available, and social autoplays muted. Motion and type carry it. A track can be laid over the render later. |
| Narrative | Problem → relief | A feature tour explains what it does; this makes someone *feel* why it exists. Reuses the site's "Stop guessing. Start watching." so video and landing page reinforce each other. |
| Product shots | Real PNGs, not mockups | `popup.png` and `notify.png` ship on the site already. This is the shot where a viewer decides the product is real; a mockup would undercut that. |

## Structure

One composition, five scenes, each a self-contained component reading its own
progress from `useCurrentFrame()`. No scene knows about any other, so each
renders standalone in the studio and can be screenshotted in isolation.

```
video/src/
  Root.tsx           registers <LaunchVideo/>
  LaunchVideo.tsx    timeline only — sequences scenes, owns the dip-to-black transitions
  theme.ts           brand tokens + the beats table (every cut point in one place)
  scenes/
    TerminalScene    0:00–4.5   typewriter, the wall slams, "Told at the wall."
    MenuBarScene     4.5–7.0    the same 91% was in the menu bar all along
    PopupScene       7.0–12.5   the real popup, five providers
    StatementScene   12.5–15.0  STOP GUESSING. / START WATCHING.
    EndCard          15.0–18.5  wordmark, usageowl.com, free · MIT · no telemetry
```

`theme.ts` holds every cut point in one `beats` table so the video can be
re-paced without hunting through five components.

## Craft rules applied

- **The hold at 0:03 is the hook.** After the rate-limit error lands, nothing
  moves for over a second, and the cursor stops blinking. Motion there would
  undercut the exact feeling the product prevents.
- **Springs, not linear tweens** — except the error box, which snaps in at full
  size. A spring there reads as playful, and hitting a rate limit is not.
- **Dip to black** on the two hard luminance jumps (dark terminal → bright
  desktop, amber → dark end card). Straight cuts read as glitches.
- **The end card holds still** for the final second so the domain can be read.
- **Amber full-bleed appears exactly once**, at the statement. It is the
  loudest frame in the video and spending it twice would waste it.

## Things that broke in the first pass

Recorded because they are the failure modes worth checking on any future edit:

1. **`popup.png` was cropped.** Set to 1180px tall inside a 1080 frame with a
   −120px drift, cutting off the header and footer. Constraint: image height
   plus absolute drift must stay under 1080. Now 940px with −46px drift.
2. **SF Symbol glyphs rendered as tofu.** `􀋨` and `􀙇` live in a private-use
   Unicode range Chromium cannot resolve. Menu bar icons are drawn as SVG now.
3. **The desktop sliver was a dead blue rectangle.** An amber wash now sits
   under the owl item so the eye lands on the 91%.
4. **Fonts pulled ~70 network requests per frame.** Weights and subsets are now
   pinned to exactly what the scenes use.
5. **The opening argued with itself.** The error printed "resets in 41 minutes"
   while the caption claimed "You had no warning" — the frame *was* a warning.
   The complaint is about *when* it arrives, so the line is now "Told at the
   wall. Not before it.", which also sets up the menu-bar reveal.
6. **The problem beat ran 6.5s.** More than double the 2-3s the PAS structure
   allows. Now 4.5s, with a typewriter on the command so it reads as live work
   being interrupted rather than a static list appearing.

## Verification

Stills rendered at the key beat of every scene and inspected before committing
to a full encode — a 25s render is too slow to iterate on blind. Then the MP4
checked for duration, dimensions, and file size.

## Output

`video/out/usageowl-launch.mp4` — H.264, CRF 18.

Source is tracked; `video/out/` and `video/node_modules/` are gitignored. The
MP4 belongs on the release page or the site, not in git history, where it would
be permanent weight.
