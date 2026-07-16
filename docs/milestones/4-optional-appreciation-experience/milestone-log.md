# Milestone 4 — Optional Appreciation Experience

## What's new in the app

- Free feedback is the clear default on the donor form (sender, reaction, optional message, send)
- Appreciation is opt-in via a checkbox toggle; amount presets and tip CTA stay hidden until enabled
- With appreciation on, viewers still get both free submit and tip/QR checkout
- Tip QR screen shows sender, amount, instructions, optional expiry, and a back action that resets the form
- QR creation errors keep the Note fields so the viewer can retry
- Hero and side copy are feedback-first instead of donation-first

## What was built

### Donor form (`DonateLive`)

- Form field `show_appreciation` (boolean) via `<.input type="checkbox" id="appreciation-toggle">`; assign derived from changeset
- Amount presets/custom wrapped in `#amount-options` only when appreciation is on
- Collapsed `validate` merges prior `amount_option` / `custom_amount` (default Rp 10.000)
- Tip CTA `#tip-submit` is `type="submit" name="_tip"` (live DOM); guarded by `:tip_submitting` + `step == :form`
- Tip submit requires `show_appreciation` truthy in submitted params before `put_tip_appreciation/1` (fail closed)
- Free CTA always available (including while appreciation is on); Enter / primary submit stays free (no `_tip`)
- Form field order: name → reaction → message → appreciation → amounts → CTAs
- Feedback-first hero/side-card/form intro copy

### Payment step

- `#payment-expiry` when Mayar returns `expires_at`
- `#payment-back` (“Kembali ke form”) calls `new_donation` / `reset_donor_form/1` (blank form, appreciation off)
- Paid thank-you CTA “Kirim lagi”; body “Pembayaranmu…”
- Abandoned tips remain `pending`; overlay celebration still only after paid confirmation

### Tests

- `donate_live_test.exs` — collapsed appreciation, tip CTA on/off, Enter→free with appreciation+amount, tip ignore when appreciation off, feedback-first copy
- `donor_qr_flow_test.exs` — enable appreciation before tip path; amount preserve without re-pick; back resets form (incl. `#tip-submit`); QR error preserves name
- `ConnCase.donor_hero_headline/0` shared by home/surface/live/feature copy locks

## Unspecified implementation decisions

- Toggle is a form-field `<.input type="checkbox">` driven by `validate` (not a separate `phx-click` event)
- Tip uses submitter `_tip` instead of `JS.push(..., form:)` (unavailable on LiveView 1.1.x)
- Enter → free is intentional (M4 free-primary); tip stays explicit click
- Back from QR resets rather than restoring prior fields (locked with product)
- When appreciation is on, both free and tip CTAs remain (locked with product)
- Expiry line omitted when Mayar does not return `expires_at`
- Full Notable branding / `/donate` redirect deferred to Milestone 6

## What the next milestone needs to know

- Milestone 5 (Unified Admin Inbox) can add Tips/Feedback filters; admin still uses `all|paid|pending`
- Donor form copy is already feedback-first; M6 can rename to Notable without redoing toggle UX
- Overlay float + tip celebration plumbing unchanged from M3

## PRD deviations

- None for Milestone 4 scope

## Verification

- `mix test` — 113 tests, 0 failures (2026-07-16)
- Review follow-up: W1–W6 + S1–S5 closed (see appreciation-review-followup plan)
- Done when checks:
  - Free feedback is the default path; appreciation reveals amount choices
  - Tip path reaches a complete QR screen with back + retryable errors
  - No celebration before payment confirmation
