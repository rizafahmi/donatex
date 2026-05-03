# ADR-017: Validate Mayar QR Image URLs And Redact QR Data From Logs

## Status

Accepted

## Date

2026-05-02

## Context

The donor flow requests a Mayar dynamic QR and then renders the returned QR image URL in the donor browser.

This integrates two risky inputs:

- a third-party API response that includes a URL which will be rendered in HTML
- webhook events that later reference the transaction id returned by that API

Because the Mayar response and webhook payloads are treated as untrusted input, the system should:

- avoid inventing identifiers that would prevent correct webhook correlation
- avoid rendering unexpected URL schemes that could be abused as an injection vector
- avoid logging usable QR content that might be sensitive or replayable while still allowing operational debugging

During real traffic testing, Mayar `POST /qrcode/create` was observed to sometimes omit `transactionId`/`id`, returning only:

```json
{
  "statusCode": 200,
  "messages": "Success",
  "data": {
    "amount": 25000,
    "url": "`https://media.mayar.club/images/resized/480/<uuid>.png`"
  }
}
```

Later production traffic showed the opposite of the earlier assumption: the QR image filename UUID can differ from the webhook `transactionId` for the same payment. That means the QR asset URL is useful for rendering and observability, but not trustworthy as the persisted payment correlation key.

## Decision

1. Prefer the Mayar QR create API response transaction identifier (`transactionId` or fallback `id`). If it is missing, query Mayar `GET /transactions/unpaid?page=1&pageSize=20` and resolve the transaction id only when there is a single fresh same-amount candidate. If no unique candidate exists, treat the response as `{:unexpected_response, body}`.
2. Validate `qr_image_url` before returning it to the caller:
   - allow `https://...`
   - allow `data:image/{png|jpeg|webp};base64,...`
   - allow `http://localhost|127.0.0.1|0.0.0.0` only when explicitly enabled via configuration for local development
3. When logging Mayar create QR failures, redact QR URL fields from logged response bodies (both known URL keys and any response keys containing `qr`).
4. Avoid using `Mix.env()` in runtime code paths (LiveView/controllers). Use runtime configuration flags instead for developer-only UI details.
5. For lifecycle logging (QR create, webhook accept/reject, admin replay), log only correlation identifiers (transaction id, donation id) and avoid logging secrets or usable QR content.
6. For Mayar QR creation success logs, include whether the transaction id came from response fields (`transactionId`/`id`) or unpaid-transaction lookup, plus whether the QR asset UUID matches the stored transaction id for observability.

## Alternatives Considered

### Resolve the transaction id from the QR asset URL

- Pros: no extra API request
- Cons: production traffic proved that the QR asset UUID can differ from the webhook transaction id; causes paid-but-unmatched donations
- Rejected

### Resolve the transaction id from recent unpaid transactions

- Pros: uses an official Mayar endpoint that exposes the real transaction `id`; avoids trusting the QR asset filename
- Cons: adds a second Mayar API request and still needs a uniqueness check when Mayar omits the id from the create response
- Accepted as the safest currently-documented fallback

### Allow any `data:image/*` URL

- Pros: simplest whitelist
- Cons: broadens attack surface (especially SVG-in-data URLs) and complicates future CSP hardening
- Rejected in favor of an explicit allowlist of expected formats

### Always allow `http://` URLs

- Pros: fewer integration surprises
- Cons: enables mixed-content risk and opens the door to non-local insecure URLs
- Rejected; only allow local insecure URLs when explicitly enabled for development

### Log full Mayar bodies for debugging

- Pros: fastest root-cause analysis when Mayar changes response shape
- Cons: may leak QR URLs into logs which can outlive the intended donor session
- Rejected; redact QR URL fields while retaining status codes and non-sensitive fields

## Consequences

- The donor flow fails closed when Mayar responses do not include a transaction identifier or safe QR URL.
- When Mayar omits `transactionId`/`id`, the app performs a follow-up unpaid-transactions lookup before showing the QR.
- Local development can still work with insecure localhost QR image URLs by enabling an explicit configuration flag.
- Operational logs remain useful while reducing the chance of QR data leakage.
