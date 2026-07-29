# ADR-024: Add A Secondary Public Q&A Questions Board

## Status

Accepted

## Date

2026-07-25

## Context

Notable is a single-user livestream donation system with two primary public surfaces (donor page and OBS overlay) plus a simple admin page. The streamer wanted a way for the audience to submit questions during a stream and upvote questions from others, surfaced as a separate secondary public route.

The existing feedback flow is free-text notes plus optional QRIS tips. A Q&A board is a distinct audience interaction: short questions, anonymous upvotes, and streamer moderation (answer/reopen/hide/restore), none of which fit the donation/feedback model.

## Decision

Add a secondary public Q&A surface as a separate bounded context rather than extending the donation/feedback domain:

- Public route `GET /questions` (`NotableWeb.QuestionLive`) for submission and voting.
- Authenticated route `GET /admin/questions` (`NotableWeb.AdminQuestionLive`) for streamer moderation (admin auth: [ADR-020](ADR-020-admin-basic-auth-for-mvp.md)).
- A new `Notable.Questions` context with its own `questions` and `question_votes` SQLite tables, separate from `donations`.
- Reuse the existing `NotableWeb.Plugs.VisitorId` signed session for anonymous identity, but store only a SHA-256 hash (`visitor_hash`) on vote rows — never the raw visitor id.
- Generalize the per-IP feedback rate limiter into `Notable.SubmissionLimiter` with namespaced keys so feedback (`{:feedback, ip}`) and question submission (`{:question, visitor_id}`) cooldowns remain independent.

Locked product rules: immediate public publication, blank name rendered `Anonim`, max 500 visible characters, one question per visitor per 10 seconds, toggle vote (one upvote per visitor per question), voting closes/reopens with answered status, no pinning, status-only answer (no written answer text), and hidden state orthogonal to answered/open status. When `create_question` fails with an `Ecto.Changeset`, re-assign that changeset to the LiveView form (`action: :insert`) so shared `<.input>`s render field errors alongside the flash.

## Consequences

- A third public surface exists alongside the donor page and overlay. It is marked `noindex, follow` so it does not dilute SEO indexing of the canonical donor page.
- The Questions context stays independent of the Donations context; no shared schema or coupling beyond the shared visitor session plug and submission limiter.
- The single-node LiveView + PubSub approach is retained; no external queue or broker is introduced.
