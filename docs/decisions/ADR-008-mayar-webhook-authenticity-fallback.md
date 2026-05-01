# ADR-008: Use A Tokenized Callback URL As The Mayar Webhook Authenticity Fallback

## Status

Accepted

## Date

2026-05-01

## Context

Donatex needs to accept payment confirmation webhooks from Mayar, and the PRD requires that only valid Mayar webhook requests can trigger donation updates and overlay alerts.

The official Mayar pages reviewed for this task document:

- webhook setup and payload fields: `https://docs.mayar.id/integration/webhook`
- webhook registration by callback URL only: `https://docs.mayar.id/api-reference/webhook/registerurlhook`
- webhook management endpoints such as test, retry, and history

Those pages do not document any of the usual authenticity features expected for webhook verification:

- no signature header name
- no HMAC algorithm
- no shared webhook secret negotiation
- no documented static source IP allowlist

That leaves the app with a real security gap if it accepts unsigned requests on a fixed public endpoint.

## Decision

For the MVP, Donatex will use a tokenized HTTPS callback URL as its webhook authenticity fallback.

- Add `MAYAR_WEBHOOK_TOKEN` to the runtime config contract.
- Register a webhook URL that embeds this token in a non-guessable path segment.
- Centralize the token check in `Donatex.Mayar.WebhookAuth`.
- Reject mismatched requests before any database writes or PubSub broadcast.
- Continue validating payload shape and correlating the event to an existing donation row.

This is an explicit fallback, not a claim that the webhook is cryptographically signed.

## Alternatives Considered

### Assume Mayar Sends An Undocumented Signature Header

- Pros: would preserve a cleaner public endpoint if true
- Cons: no official documentation or verified example supports this today
- Rejected because security assumptions must be based on documented behavior, not hope

### Accept Unsigned Webhooks On A Fixed Public Route

- Pros: simplest implementation
- Cons: anyone who discovers the endpoint could forge donation events
- Rejected because it violates the PRD security requirement

### Require A Custom Header Secret

- Pros: keeps the secret out of the URL path
- Cons: the Mayar docs reviewed for this task do not document custom outbound header configuration for webhook delivery
- Rejected because there is no evidence the platform supports it

## Consequences

- Task 20 can implement webhook auth without reopening the runtime config contract.
- The fallback model is materially safer than a completely open webhook endpoint.
- The fallback model is still weaker than signed webhooks because it does not protect against payload tampering if the tokenized URL is exposed.
- Production deployments should avoid logging full request URLs where possible to reduce accidental token leakage.
- Production deployments should use long, random tokens (for example 20+ characters) to keep the callback URL non-guessable.

## Follow-Up

- Implement the actual token enforcement in `Donatex.Mayar.WebhookAuth` and the webhook controller.
- Re-check Mayar docs and dashboard behavior before production launch in case official signing support appears.
- Replace the token fallback with documented request signing if Mayar exposes it later.
