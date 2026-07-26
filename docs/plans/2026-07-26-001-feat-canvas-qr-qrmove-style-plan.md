# Plan: Canvas QRMove-style `/qr` (#22)

**Date:** 2026-07-26  
**Issue:** https://github.com/rizafahmi/donatex/issues/22  
**Branch:** `feat/22-canvas-qr`

## Goal

Replace the SVG + lightning-bolt overlay on `/qr` with a **canvas** matrix animation inspired by [QRMove](https://nicopr.fr/qrmove/), using Rosé Pine brand colors, while keeping the code phone-scannable.

## Owner decision

Option **(2)** — canvas approach like QRMove (simpler). Not `@bitjson/qr-code`.

## Assumptions

- Scannability remains a hard gate: dark modules on white, full module fill each frame; animation is color/phase motion within dark tones + light accent sparkle that does not erase modules.
- Hidden SVG retained for clean PNG download (unanimated).
- Does not close parent #6; open PRs #16/#20 may conflict later.

## Approach

1. LiveView: render `<canvas id="qr-canvas">` with `data-matrix` JSON; keep `#qr-svg-hidden` for download.
2. `Hooks.QrCode`: init canvas from matrix; `requestAnimationFrame` loop with QRMove-like traveling phase; respect `prefers-reduced-motion` (static draw).
3. CSS: size the canvas; remove reliance on bolt overlay for `/qr` (leave unused overlay CSS harmlessly or trim if only used here).
4. Tests: assert canvas + data-matrix + hidden SVG; drop overlay assertions.

## Files

- `lib/donatex_web/live/qr_code_live.ex`
- `assets/js/app.js`
- `assets/css/app.css`
- `test/donatex_web/live/qr_code_live_test.exs`

## Verification

- `mix test test/donatex_web/live/qr_code_live_test.exs`
- `mix ci`
- Manual: open `/qr`, confirm animation + phone scan of encoded `Config.base_url()`
