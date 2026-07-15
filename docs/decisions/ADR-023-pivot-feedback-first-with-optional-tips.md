# ADR-023: Pivot From Donation-First To Feedback-First With Optional Tips

## Status

Accepted

## Context

During live streams, the donation framing created negative audience sentiment. A viewer commented that the streamer "is already rich, why still open for donation?" — revealing that the word "donation" implies financial need and invites judgment. Donation rates were low not because viewers didn't want to engage, but because the payment-first framing raised the barrier to interaction and introduced social friction.

The existing system requires every interaction to be a monetary transaction: name → amount → message (optional) → QR → payment. Viewers who want to say something encouraging but can't or won't pay have no way to participate.

## Decision

Pivot the product narrative from a donation platform to a feedback and appreciation platform. The core interaction becomes sending a feedback note with a mandatory emoji reaction. Monetary tips become an optional add-on, hidden behind a toggle.

### Specific changes

**Form flow:**
- Name (required) → Reaction emoji (required, one of: bad/ok/good/great) → Message (optional) → "Show appreciation" toggle (collapsed) → Amount/QR (only if toggled)

**Schema:**
- Add `reaction` field (string, required, one of `bad | ok | good | great`)
- Make `amount` nullable (nil = feedback-only)
- Add `"sent"` status for feedback-only Notes (statuses become `pending | paid | sent`)
- Feedback-only Notes are created with `alerted = true` (no overlay recovery)

**Overlay:**
- Single `/overlay` route with two visual modes
- Floating emoji reactions for feedback-only Notes (ambient, ephemeral, 3–4 seconds, multiple simultaneous, random movement)
- Existing celebration alert (confetti, sound, sequential queue) for confirmed tips
- No overlay recovery for feedback-only Notes — they are ephemeral

**Spam protection:**
- Server-side rate limit: 1 feedback per 10 seconds per IP (ETS-based)
- Tips are exempt from rate limiting (payment is the throttle)

**Routing:**
- Public page moves to `/`
- `/donate` redirects to `/`

**Branding:**
- User-facing name becomes "Notable"
- Codebase stays `Donatex` internally

**Admin:**
- Unified table showing both feedback and tips
- Filters: `all | tips | feedback`
- Replay button only on paid tips

## Alternatives Considered

### Rename the core entity from Donation to Note

- Pros: internal code matches the new narrative
- Cons: massive churn across modules, tests, and schema for a cosmetic change
- Rejected in favor of narration-only pivot with the existing entity

### Show feedback-only Notes as full overlay alerts

- Pros: consistent treatment for all interactions
- Cons: free messages would overwhelm the overlay; no visual hierarchy between free and paid
- Rejected because floating emojis create a clear ambient-vs-celebration distinction

### Remove the "bad" reaction to prevent negative overlay content

- Pros: eliminates troll vector
- Cons: limits authentic feedback; the streamer explicitly wanted the full range
- Rejected but the emoji pool was softened (😅 🫠 💤 🙈 instead of 😞 😭 🙅 🤡) to be constructive rather than hostile

### Two separate overlay routes for feedback and tips

- Pros: simpler per-route logic
- Cons: streamer must configure two OBS sources; harder to maintain visual consistency
- Rejected in favor of a single `/overlay` route with two rendering modes

## Consequences

- Lowers the barrier for audience engagement — viewers can participate without paying
- Removes the "asking for money" stigma that suppressed both engagement and revenue
- Tips become a deliberate act of appreciation rather than an expected obligation, which may increase per-tip amounts even if volume decreases
- Introduces a new spam vector that requires rate limiting (not needed when payment was the gate)
- The `donations` table now contains two kinds of records (feedback-only and tipped), adding complexity to queries and admin filters
- Existing overlay recovery logic is unaffected — only `status = paid AND alerted = false` rows are recovered
- The `Donation` schema accumulates semantic drift (a "donation" that has no amount) which may warrant a future rename if the pivot proves permanent
