# Milestone 6 Log — Notable Branding and Routing

## What's new in the app
- **Polish of / (Donor View) surfaces**: Replaced unpolished class-based icon selectors, cleaned up em-dash usages, set a dynamic page title ("Kirim Feedback & Tips · Live Stream Support"), and implemented a dynamic focus and active/selected visual state for the reaction radio selectors (which previously had no visual feedback upon selection).
- **Narrative Flip to Feedback-First**: Updated wording across the `/` page, status badge ("Kotak Masukan Terbuka"), informational cards, and payment/success screens. The new copy focuses on leaving messages and feedback as the primary path, and clarifies that tips are optional.
- **Offline / Post-Stream Accommodation**: Modified the payment and success screen descriptions to explicitly clarify that feedback and tips are accepted and stored safely even when the streamer is offline (with alerts automatically entering a recovery queue to be played once the stream starts).
- **Branding updates**: Modified the default layout tab title suffix from "· Phoenix Framework" to "· Live Stream Support". Updated the admin subtitle to use "notes and tips" instead of "donations" to align with the single-streamer Notable branding guidelines.
- **Route redirects**: Added a redirect mapping for `/donate` that automatically forwards users back to the root path `/` where the donor page is mounted.
- **Title Bar cleanups**: Removed em-dashes from the OBS overlay terminal window title (replaced with `notable-terminal | alert`).

## What was built
### Routes and Controllers
- Route `get "/donate", PageController, :redirect_to_root` in [router.ex](file:///Users/riza/code/notable/lib/notable_web/router.ex#L32)
- Action `redirect_to_root/2` in [page_controller.ex](file:///Users/riza/code/notable/lib/notable_web/controllers/page_controller.ex#L8-L10)

### UI Components and LiveViews
- Page titles for `DonateLive` (`"Kirim Feedback & Tips"`), `OverlayLive` (`"OBS Overlay"`), and `AdminLive` (`"Admin Console"`)
- Cleaned up em-dashes across [donate_live.ex](file:///Users/riza/code/notable/lib/notable_web/live/donate_live.ex), [overlay_live.ex](file:///Users/riza/code/notable/lib/notable_web/live/overlay_live.ex), and [admin_live.ex](file:///Users/riza/code/notable/lib/notable_web/live/admin_live.ex)
- Dynamic `reaction_classes/1` visual state styling for the reaction radio selector cards in `DonateLive`
- Refactored icon tags to use the standardized `<.icon>` component in `DonateLive`

### Verification and Tests
- Page controller redirect integration test in [page_controller_test.exs](file:///Users/riza/code/notable/test/notable_web/controllers/page_controller_test.exs)
- Test copy assertions in [donate_live_test.exs](file:///Users/riza/code/notable/test/notable_web/live/donate_live_test.exs), [donate_live_tip_hardening_test.exs](file:///Users/riza/code/notable/test/notable_web/live/donate_live_tip_hardening_test.exs), and [donor_qr_flow_test.exs](file:///Users/riza/code/notable/test/notable_web/features/donor_qr_flow_test.exs)

## Unspecified implementation decisions
- Kept the default redirect code inline in the `PageController` module to reuse the existing structure.

## Corrective branding audit — 2026-07-18
- Re-audited user-visible copy across the donor flow, QR states, overlay, shared navigation, and authenticated admin after the initial milestone completion claim.
- Replaced remaining donation-first copy in appreciation validation and persistence errors with tip terminology.
- Replaced remaining admin missing-record messages with Note terminology.
- Changed the shared public-route navigation label from `Donate` to `Feedback`.
- Changed the visible overlay title bar from `notable-terminal | alert` to `notable-terminal | alert`.
- Kept internal `Notable`/`Donations` modules, schema terminology, DOM IDs, event names, PubSub topics, and logs unchanged, as required by the PRD.
- Added focused regressions for each corrected user-visible string.

### Final verification evidence
- Scoped visible-string audit found no remaining donation-first copy; remaining matches are internal identifiers, logs, comments, or the intentionally retained font-family asset name.
- `./init.sh` passed: 140 tests, 0 failures; Credo clean; Dialyzer 0 errors; duplication check passed; architecture policy passed.

## Next steps
- Proceed to Milestone 7: End-to-end refinement, smoke testing, and final release preparation.
