# Risks and Open Questions

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Mayar webhook authenticity mechanism is undocumented | High | Resolve it in Task 9 before finalizing webhook security implementation |
| Mayar QR creation response shape is under-documented in the public collection | Medium | Freeze an internal client contract in Task 10 and confirm against sandbox responses |
| Donor live-update requires correlating a browser session with a later webhook event | Medium | Store local donation rows at QR creation time and subscribe the donor page to updates by local donation ID or Mayar transaction ID |
| Overlay queue edge cases can create duplicate or overlapping alerts | Medium | Keep queue logic small, test recovery and timing behavior directly, and avoid extra queue infrastructure in MVP |
| Webhook retries and delivery timing are not fully documented | Medium | Document observed behavior during sandbox testing and rely on DB dedupe and recovery queue |

## Open Questions

- Does Mayar expose any undocumented webhook signature header in the dashboard or live requests, or must MVP authenticity use a fallback strategy?
- What exact response fields does `POST /qrcode/create` return in practice for a successful dynamic QR creation?
- Should `transactionStatus = paid` or `status = SUCCESS` be treated as the primary condition for donation confirmation, or both?
