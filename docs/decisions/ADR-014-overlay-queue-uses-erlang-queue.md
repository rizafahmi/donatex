# ADR-014: Use Erlang :queue For Overlay Alert FIFO

## Status

Accepted

## Date

2026-05-02

## Context

`NotableWeb.OverlayLive` keeps a runtime FIFO queue of donation alert payloads.

The simplest representation is a list:

- recovery seeds a list of payloads
- PubSub appends with `queue ++ [payload]`
- the overlay shows `[next | rest]`

This is correct but not efficient under bursts, because appending to a list with `++` is `O(n)` and copies the whole queue each time.

Even though Notable is a single-streamer MVP, the overlay should remain stable under short spikes (multiple donations arriving close together) without introducing a separate OTP queue process or an external broker.

## Decision

Represent the overlay FIFO queue with Erlang `:queue`:

- enqueue with `:queue.in/2`
- dequeue with `:queue.out/1`
- initialize from recovery results with `:queue.from_list/1`

The queue remains transient LiveView state, and durable recovery still comes from the database.

## Alternatives Considered

### Keep a list and accept the cost

- Pros: simplest code
- Cons: `O(n)` enqueue copies the full list on every paid event; worst-case CPU/memory spikes during bursts
- Rejected to keep the overlay process stable with a minimal code change

### Dedicated GenServer queue

- Pros: isolates queue operations
- Cons: adds another process boundary without solving the underlying list append cost; still needs DB-backed recovery semantics
- Rejected to keep the architecture aligned with ADR-003

## Consequences

- Overlay enqueue/dequeue becomes `O(1)` and avoids repeated list copying.
- FIFO semantics stay identical.
- The queue remains local to the overlay LiveView, preserving the MVP architecture constraints.

