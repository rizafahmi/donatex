# Spec: Make donation page more general/agnostic (#1)

## Goal
Generalize the `/` page copy so it works for talks, webinars, and events — not just livestreaming. Remove streaming-specific language ("streamer", "stream", "overlay stream") while preserving all existing functionality (free feedback, optional QRIS tip, payment flow, reaction overlay).

## Acceptance criteria
1. The `/` page copy contains no streaming-specific terms ("streamer", "streaming", "stream") in user-visible text or structured data (JSON-LD).
2. The meta description (both in `DonateLive.mount/3` and `SEO` plug) is generic — references feedback/tips, not streaming.
3. The feature list item formerly labelled "Overlay Stream" uses a generic label (e.g., "Reaksi Live") and generic description.
4. The payment-step and paid-step info text uses "acara" (event) instead of "stream" for offline references.
5. The form description no longer says "untuk mendukung stream" — just "untuk mendukung" + creator link.
6. JSON-LD structured data descriptions are generic (no "streamer" references).
7. All existing tests pass (updated to match new copy where assertions checked old strings).
8. `mix format --check-formatted`, `mix credo --strict`, `mix test`, `mix dialyzer` all pass.

## Non-goals / out of scope
- No structural/page layout changes.
- No changes to the overlay (`/overlay`) or admin (`/admin`) pages.
- No new configuration system or env-var-driven copy.
- No changes to the QRIS payment flow, form validation, or data model.
- No changes to the `home.html.heex` template (route is commented out / not served).
- No multi-event or per-session customization.

## Constraints
- Preserve the rizafahmi.com personal links and UTM parameters (they are branding, not streaming-specific).
- Preserve the "Notable" brand name in JSON-LD and page title.
- Keep all form fields, validation, and submit behavior unchanged.
- Copy remains in Indonesian (Bahasa Indonesia).
