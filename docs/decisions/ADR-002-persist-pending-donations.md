# ADR-002: Persist Donations At QR Creation Time

## Status

Accepted

## Context

The product requires a `pending | paid` donation lifecycle. That status model only has clear meaning if a local donation record exists before payment confirmation.

## Decision

Create a local donation row when the donor submits the form and the app generates a Mayar QR. Update that row to `paid` when the corresponding Mayar webhook is accepted.

## Alternatives Considered

### Only create local rows on webhook receipt

- Pros: fewer local rows for abandoned payments
- Cons: `pending` becomes meaningless, donor page correlation is harder, live-update after payment is harder, local observability is worse
- Rejected because it weakens the intended donation lifecycle and complicates the donor success flow

## Consequences

- The system can show a real waiting state tied to a local record
- The donor page can transition from pending to paid in real time
- The implementation must handle failed QR creation carefully so it does not leave misleading pending rows without a defined recovery path
