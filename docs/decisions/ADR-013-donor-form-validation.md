# ADR-013: Validate Donor Form Input With Ecto Changesets In LiveView

## Status

Accepted

## Date

2026-05-02

## Context

Notable has a public donor flow where untrusted input is collected via LiveView:

- Donor name (required)
- Donation amount option (preset or custom)
- Custom amount (required only when custom is selected)
- Message (optional)

The donor flow must work well on mobile, but client-side constraints (HTML `required`, `maxlength`, etc.) are not a security boundary.
We need consistent server-side validation that integrates with Phoenix 1.8 form rendering (`to_form/2`) and the shared `<.input>` component.

## Decision

Implement donor form validation using `Ecto.Changeset` in `NotableWeb.DonateLive`, backed by a dynamic schema (`{%{}, types}`) and `cast/3`:

- Validate required fields on submit (and on change for LiveView validation UX).
- Enforce server-side length bounds for text fields:
  - `donor_name` max 64 characters
  - `message` max 280 characters
- Validate amount selection by:
  - accepting preset amounts from an allowlist
  - requiring and validating `custom_amount` only when `amount_option == "custom"`
  - enforcing `custom_amount >= 1000` and `custom_amount` in multiples of 1000 to match the mobile-friendly input step size
- When free-feedback or tip persistence returns an `Ecto.Changeset` error, copy overlapping field errors onto the LiveView form changeset (with `action: :insert`) so shared `<.input>` components render them alongside the flash, instead of flash-only state

## Alternatives Considered

### Rely on HTML attributes only

- Pros: minimal code
- Cons: bypassable (non-browser clients, devtools, crafted requests), inconsistent error UX
- Rejected because the donor page is a public boundary and must enforce input constraints server-side.

### Manual validation without a changeset

- Pros: avoids `Ecto.Changeset` dependency in the LiveView module
- Cons: harder to render errors consistently with `<.input>` and `to_form/2`, more custom glue code
- Rejected to keep form handling aligned with Phoenix conventions and minimize bespoke code.

### Create a dedicated embedded schema module for the form

- Pros: explicit type/field definition in its own module, reusable for future steps
- Cons: additional modules early in the MVP with minimal benefit over a dynamic schema
- Rejected for now; we can extract to a module later if the donor flow becomes multi-step and needs shared validation.

## Consequences

- LiveView handles donor input with a single, consistent validation mechanism.
- Server-side constraints prevent oversized input from bypassing client-side limits.
- Future donor flow steps (QR review, pending/paid UI) can reuse the changeset or extract it to a dedicated module if needed.
