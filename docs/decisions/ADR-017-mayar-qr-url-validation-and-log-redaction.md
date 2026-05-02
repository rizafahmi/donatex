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

In that case, the `<uuid>` filename component appears to be stable and usable for webhook correlation.

## Decision

1. Prefer the Mayar QR create API response transaction identifier (`transactionId` or fallback `id`). If it is missing, derive the transaction id from the QR image URL path when it contains a UUID filename (e.g. `.../<uuid>.png`). If neither is available, treat the response as `{:unexpected_response, body}`.
2. Validate `qr_image_url` before returning it to the caller:
   - allow `https://...`
   - allow `data:image/{png|jpeg|webp};base64,...`
   - allow `http://localhost|127.0.0.1|0.0.0.0` only when explicitly enabled via configuration for local development
3. When logging Mayar create QR failures, redact QR URL fields from logged response bodies (both known URL keys and any response keys containing `qr`).
4. Avoid using `Mix.env()` in runtime code paths (LiveView/controllers). Use runtime configuration flags instead for developer-only UI details.
5. For lifecycle logging (QR create, webhook accept/reject, admin replay), log only correlation identifiers (transaction id, donation id) and avoid logging secrets or usable QR content.
6. For Mayar QR creation success logs, include whether the transaction id came from response fields (`transactionId`/`id`) or was derived from the QR URL path (useful when confirming webhook correlation against real traffic).

## Alternatives Considered

### Derive a transaction id when Mayar omits one

- Pros: keeps the donor flow going if Mayar omits `transactionId` but embeds a stable UUID in the QR URL
- Cons: breaks webhook correlation if Mayar webhooks reference the real transaction id; increases risk of misattribution
- Accepted only when the derived id is clearly Mayar-provided (a UUID in the QR URL path); still fail closed if no stable identifier can be extracted

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
- Local development can still work with insecure localhost QR image URLs by enabling an explicit configuration flag.
- Operational logs remain useful while reducing the chance of QR data leakage.
