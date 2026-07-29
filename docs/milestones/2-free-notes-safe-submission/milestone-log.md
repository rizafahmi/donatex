# Milestone 2 — Free Notes with Safe Submission

## What's new in the app

- Viewers can send free feedback (sender + reaction + optional message) without paying
- Accepted free Notes show a thank-you screen and reset the form
- The same IP cannot send another free Note for 10 seconds; rejected attempts keep the form fields
- Tip checkout remains available as a secondary “Lanjut tip” action
- Admin defaults to the All filter and lists free Notes with no amount
- New free Notes appear live in admin; free Notes do not offer Replay Alert

## What was built

### Persistence

- `Donation` status includes `"sent"`; `amount` and `mayar_transaction_id` are nullable for free Notes
- Migration `priv/repo/migrations/20260716093000_allow_feedback_without_payment_details.exs`
- `Donations.create_feedback/1` persists `status: "sent"`, `alerted: true`, without payment fields

### Rate limiting

- `Notable.FeedbackRateLimiter` — supervised GenServer owning an ETS table
- 10-second per-IP cooldown for accepted free Notes only; tips are exempt
- IP source: LiveView `peer_data` via Endpoint `connect_info` (no `x-forwarded-for`)

### Donor UI (`DonateLive`)

- Primary submit: free feedback → thank-you (`:thanks`) + blank form
- Secondary: “Lanjut tip” keeps the existing Mayar QR path
- Cooldown flash preserves entered fields on reject
- Accepted free feedback broadcasts `{:donation_created, feedback}` on `donations:created`

### Admin (`AdminLive`)

- Default filter is `all` (was `paid`)
- Amount line omitted when `amount` is nil; `DonationPresenter.format_idr/1` accepts nil
- Replay Alert only for `status == "paid"`

### Key tests

- `test/notable/donations_test.exs` — `create_feedback/1`
- `test/notable/feedback_rate_limiter_test.exs`
- `test/notable_web/live/donate_live_test.exs` — free submit + broadcast
- `test/notable_web/live/donate_live_feedback_cooldown_test.exs`
- `test/notable_web/features/admin_filters_test.exs` — default all + free Notes
- `test/notable_web/features/admin_replay_test.exs` — no replay for free Notes

## Unspecified implementation decisions

- Rate limiter is process-local ETS (single-node MVP); restarts clear cooldown state
- Cooldown key is the peer IP tuple from LiveView connect info; missing peer data skips limiting
- Admin filters remain `all|paid|pending` until Milestone 5 Tips/Feedback filters
- Free Notes are stored permanently (same `donations` table) even though overlay float recovery is out of scope until M3
- Stats strip still counts paid/pending only; `sent` does not affect paid_sum

## What the next milestone needs to know

- Milestone 3 (Floating Overlay Reactions) should consume free-Note creation (likely the existing `donations:created` broadcast or a dedicated topic) for ephemeral emoji floats
- Free Notes are already `alerted: true` at insert — do not treat them as tip celebration recovery candidates
- Reaction pools and float animation are not implemented yet; only persistence + admin visibility exist
- Tip celebration path on `/overlay` is unchanged

## PRD deviations

- None for Milestone 2 scope. Tips/Feedback admin filters, collapsed appreciation toggle, and overlay floats remain deferred to later milestones as planned.

## Verification

- `mix test` — 95 tests, 0 failures (2026-07-16)
