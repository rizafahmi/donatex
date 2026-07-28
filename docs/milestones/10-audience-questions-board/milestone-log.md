# Milestone 10 — Audience Questions Board

## Outcome

- A secondary public Q&A surface at `/questions` lets audience members submit questions (optionally named, otherwise rendered `Anonim`) and toggle one anonymous upvote per question.
- Questions publish immediately to a WIB-grouped board. Today is ranked open-before-answered, then votes descending, then oldest first. Prior WIB dates collapse and load on demand.
- Voting closes when a question is answered and reopens on reopen. Hiding is orthogonal to answered/open status.
- An authenticated `/admin/questions` moderation page lets the streamer answer, reopen, hide, and restore. No edit, delete, pin, or written-answer controls.
- Public and admin views converge in real time via the `questions` PubSub topic after committed changes.
- Raw visitor identifiers are never persisted or logged; only a SHA-256 hash of the signed session visitor id is stored on vote rows.

## Implementation

### Persistence / domain

- Migration `20260725120000_create_questions.exs`: `questions` (binary UUID, nullable name, required body ≤500, status default `open`, `hidden_at`, UTC timestamps) and `question_votes` (binary UUID, question FK cascade delete, `visitor_hash`, UTC timestamps). Unique `(question_id, visitor_hash)`, question date/order index, and a vote aggregation index.
- Schemas `Donatex.Questions.Question` and `Donatex.Questions.QuestionVote`. Public creation only casts `name`/`body`; blank name becomes `nil`; body trimmed/required/max 500; name max 64; `status` and `hidden_at` protected. Separate status/hide/restore changesets.
- Context `Donatex.Questions`: create/get, `create_question!/1` test helper, SHA-256 `hash_visitor_id/1` (public for LiveView use), transactional vote toggle, voting rejects missing/answered/hidden questions, `mark_answered`/`reopen`/`hide`/`restore`, WIB helpers using fixed UTC+7 (Asia/Jakarta has no DST) with SQLite `date(inserted_at, '+7 hours')`, ranked date queries, and PubSub on `questions`.
- A concurrent vote insert that loses the unique-index race returns `{:error, :already_voted}`; `QuestionLive` treats that result as a board reload so the UI converges on the single persisted vote instead of crashing.
- `list_date_summaries/1` accepts `include_hidden: true` for admin; `list_questions_for_date/2` supports `visitor_hash` and `include_hidden`.

### Limiter / public board

- Generalized the specialized feedback rate limiter into `Donatex.SubmissionLimiter` (supervised in `Donatex.Application`) with namespaced keys: `{:feedback, ip}` and `{:question, visitor_id}`. Old `FeedbackRateLimiter` source and test removed; feedback behavior and cooldown tests updated.
- `DonatexWeb.QuestionLive` at `/questions`: form discloses that a supplied name is public; signed visitor session drives submit/vote; immediate publication; 10-second submission cooldown; failed/rate-limited submissions preserve fields and release the reservation; today ranked open→answered, votes desc, oldest first; previous WIB dates collapsed and loaded on expand; vote toggle state; answered voting disabled; PubSub refresh; WIB midnight rollover; deterministic `handle_info({:set_current_now, %DateTime{}}, socket)` test seam.
- Navigation link and `noindex, follow` SEO metadata added.

### Admin moderation

- `DonatexWeb.AdminQuestionLive` at `/admin/questions` inside the existing `[:browser, :admin]` pipeline. Date-grouped board including hidden questions; answer/reopen/hide/restore controls; hidden state orthogonal to answered/open; PubSub refresh; canonical and `noindex, nofollow` metadata; link from `/admin`.

## Verification

- Migration test, schema tests, context tests, limiter tests, public LiveView tests, admin LiveView tests, and a focused end-to-end journey test (`test/donatex_web/features/questions_journey_test.exs`) covering submit → cross-browser upvote → rank change → admin answer → public vote disabled → reopen → vote enabled → hide → public removal → restore.
- Identity isolation: two tabs sharing one visitor session cannot create duplicate vote rows (toggle semantics); two distinct sessions vote independently.
- No raw visitor id leakage: persistence asserts every `visitor_hash` is a 64-char SHA-256 distinct from the raw id; a log-capture test refutes the raw id appears during submit/vote.
- Issue #29 regression coverage injects the `:already_voted` result, verifies the LiveView survives, and confirms the board still shows exactly one persisted vote. Documentation/lint housekeeping passed changed-file formatting, warnings-as-errors compilation, strict Credo, Dialyzer, zero-clone ExDNA, and Reach architecture/smell checks; tests were intentionally left to the pipeline test phase.
- Full quality gate: `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix credo --strict` (clean across 80 files), `mix dialyzer` (0 errors), `mix ex_dna --max-clones 0` (no duplication), `mix reach.check --arch --smells` (OK), and `mix test` — **248 tests, 0 failures** (verified across three consecutive `mix test` runs).
- Stabilized a flaky realtime-reorder LiveView test by giving the two questions explicit distinct `inserted_at` values, matching the deterministic setup already used by the ranking test in the same file.
- Follow-up stabilization: restored OBS Overlay + `/questions` listings in `priv/static/llms.txt` (and SEO assertions), and set Questions `DataCase` tests to `async: false` to avoid intermittent SQLite `Database busy` failures under parallel sandbox owners.

## Risks / Notes

- Fixed UTC+7 is intentional for Asia/Jakarta (no DST). If the streamer's timezone ever changes, the WIB grouping helpers must be revisited.
- The simple single-node LiveView + PubSub approach is retained; no external queue/broker was introduced (per project constraints).
