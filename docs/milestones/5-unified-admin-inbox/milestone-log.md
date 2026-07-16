# Milestone 5 — Unified Admin Inbox

## What's new in the app

- Admin inbox filters are **All / Tips / Feedback** (All default); paid/pending status filters are gone
- Newest-first cards show sender, reaction, type (Tip/Feedback), time, status, optional message, and amount only for tips
- Replay is offered and enforced only for **paid tips** (UI + server-side guard)
- Free feedback and tip payment updates still appear live on the matching filters
- Empty state copy is Notes-oriented (“No notes yet”)

## What was built

### Context (`Donatex.Donations`)
- `list_donations(:tips|"tips")` — rows with non-nil `amount`
- `list_donations(:feedback|"feedback")` — rows with `status == "sent"`
- Existing `:all` / `:paid` / `:pending` clauses retained for other callers/tests

### Admin LiveView (`DonatexWeb.AdminLive`)
- Filter bar: `@filters ~w(all tips feedback)`
- Live `donations:created` matching for tips (pending) and feedback (sent)
- Live `donations:paid` / `donations:alerted` refresh on `all` and `tips`
- Cards: reaction label, type, `<time>`, status badge (`data-status`, sent styling), amount id only when present
- `replay` gated by `replayable?/1` (paid + amount); error flash otherwise
- Mark Paid kept for pending tips
- Notes-oriented empty state

### Presenter (`DonatexWeb.DonationPresenter`)
- `reaction_label/1`, `note_type/1`, `format_timestamp/1`

### Tests
- `test/donatex/donations_test.exs` — tips/feedback list filters
- `test/donatex_web/features/admin_filters_test.exs` — filters, cards, live updates, empty state
- `test/donatex_web/features/admin_replay_test.exs` — forced replay reject for free notes

## Unspecified implementation decisions

- Tip = `amount != nil`; Feedback = `status == "sent"`
- Timestamp format: `Calendar.strftime(..., "%-d %b %Y, %H:%M")` (UTC as stored)
- Reaction labels match donor form: Bad / Okay / Good / Great
- Mark Paid retained as ops escape hatch (not banned by PRD)
- `:paid` / `:pending` list_donations clauses left in context for now

## What the next milestone needs to know

- Admin product language is Notes/Tips/Feedback; donor + overlay paths unchanged
- Milestone 6 branding / Notable rename can update remaining “donation” strings in admin header/subtitle if desired
- Overlay float + tip celebration plumbing unchanged

## PRD deviations

- None for Milestone 5 scope

## Verification

- `mix compile --warnings-as-errors` — clean
- `mix test` — 134 tests, 0 failures (2026-07-16)
- Done when checks:
  - All/Tips/Feedback produce correct newest-first cards
  - Incoming free notes and payment updates appear live on matching filters
  - Nil amounts render safely (no amount element for feedback)
  - Replay visible and functional only on paid tips (UI + event guard)
