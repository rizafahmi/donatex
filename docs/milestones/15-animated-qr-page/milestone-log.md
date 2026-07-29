# Milestone 15 — Artistic animated `/qr` page

Issue: [#6](https://github.com/rizafahmi/notable/issues/6) — make the QR code page more artistic and animated.

## Starting state (found, not assumed)

Verified against unmodified `origin/main` (`51545aa`) in a browser, not by reading code.
Three defects were live:

1. `/qr` and `/qr-overlay` rendered a **blank white card** — no QR at all.
2. The PNG download **threw**: the page CSP allows `img-src 'self' data: https:`, and the hook loaded the SVG through a `blob:` URL.
3. Even with a CSP-legal URL, the SVG rasterised at **150×150** instead of 280×280.

Root cause of (1) was a stale-branch merge, not a CSS slip:

- `0c8874f` (#23) moved `/qr` to canvas — added the `_initCanvasQr` hook, deleted the overlay CSS, and put `<canvas id="qr-canvas">` inline in `qr_code_live.ex`.
- `009620e` (#12) was merged **on top** (`git merge-base --is-ancestor 0c8874f 009620e` → true) from a base predating #23, and reverted `/qr` to the pre-canvas SVG + DOM-overlay markup via `QrComponents`.
- That left markup whose CSS had already been deleted. `.qr-svg-base` is a flex item and `EQRCode.svg(viewbox: true)` emits a viewBox *instead of* `width`/`height`, so the SVG had no intrinsic size and collapsed to 0×0.

Proof: setting `.qr-svg-base{width:280px;height:280px}` on the live page took `svgRect` from 0 to 280.

## Approach

Reconnected the canvas path #23 already shipped rather than resurrecting the DOM-overlay CSS — the canvas hook and `.qr-canvas` styles were still present and orphaned, and canvas is where issue #6 points.
The `QrCanvas` hook now lives on the `<canvas>` element itself, so `/qr-overlay` animates too (it has no page-level hook and was also blank).

## The scannability invariant

The key finding, caught by a decode test rather than by eye:

> **The luminance budget is per-pixel, not per-module-average.**

The intuitive model — "a bright bolt is fine if it covers a small share of the module, because the average stays dark" — is wrong.
Binarisers threshold individual pixels, so a bright glyph punches holes in its module however thin it is.
A first attempt with neon foam/rose bolts at 12.6% coverage passed every luminance-average check and **failed to decode**.

Measured edge: sweeping a neutral grey bolt against the real matrix at 6–20 px per module, decoding held through relative luminance **0.262** and first failed at **0.305**.
`Notable.Qr` sets the ink budget at **0.16**, roughly half the failure point.

Consequences that shaped the design:

- Bolts are saturated jewel tones at **full opacity** (`#31748f`, `#9d5477`, `#6b57a8`), sitting just under the budget — vivid rather than washed out by alpha.
- Because safety is per-pixel, **glyph size is free**, so the bolt is drawn at `bolt_scale: 0.86`.
- Colour animation interpolates only *between* palette colours. Relative luminance is convex in sRGB, so a blend can never exceed its lighter endpoint — every intermediate frame is inside the budget by construction.
- The scanner sweep composites with `multiply`, which can only darken. It tints the white quiet zone without ever lifting a dark module toward the threshold.

## Verification

`mix ci`: 335 tests, 0 failures; credo `--strict` clean; dialyzer 0 errors; ex_dna 0 clones; reach architecture OK.

Decode evidence (`cv2.QRCodeDetector`, exact match on `https://feedback.rizafahmi.com`):

| Source | Result |
| --- | --- |
| `render_rgb(variant: :plain)` | decodes; survives downscale to 70px, 13px blur, 0.1 contrast |
| `render_rgb(variant: :animation_peak)` | decodes; identical margins — bounds every animation frame |
| Live `/qr`, 20 screenshots across the cycle | 20/20; smallest 90px, blur ≤15px |
| Live `/qr`, mobile 260px card, 8 screenshots | 8/8; smallest 70px |
| Reduced motion | decodes; pixel-identical across frames (genuinely static) |
| Download SVG rasterised | decodes; exactly 2 colours, 1120×1120 output |

## Notes for future sessions

- The scannability tests need OpenCV; CI installs `opencv-python-headless`. They `flunk` rather than skip when it is missing, so the guarantee cannot silently disappear.
- `Notable.Qr.palette/0` is the single source of truth and is handed to JS via a data attribute. Adding a colour directly in `app.js` would escape the Elixir budget tests.
- The scanner sweep is deliberately gentle: its brightness is capped by the contrast it must keep against the brightest ink. Making it more dramatic means lowering the bolt luminance.
