# Roadmap and Handoff

## Parallelization Opportunities

- After Task 8, one agent can handle Tasks 9-13 while another prepares donor UI shell work in Task 14.
- After Task 21, donor live-update work in Task 17 and overlay work in Tasks 22-27 can proceed in parallel.
- After Task 27, admin work in Tasks 28-31 and documentation/logging work in Tasks 32-33 can proceed in parallel.

## Suggested LLM Handoff Order

1. Tasks 1-4 to establish the app and route skeleton.
2. Tasks 5-8 to land the persistence model.
3. Tasks 9-13 to lock the Mayar integration contract.
4. Tasks 14-17 for the donor flow.
5. Tasks 18-21 for webhook ingestion.
6. Tasks 22-27 for overlay recovery and queue behavior.
7. Tasks 28-31 for admin replay.
8. Tasks 32-34 for operational polish and final verification.

## Planning Verification

- [ ] Every task has acceptance criteria.
- [ ] Every task has a verification step.
- [ ] Dependencies are ordered from foundation to feature slices.
- [ ] No task is intentionally XL-sized.
- [ ] Checkpoints exist between major phases.
- [ ] Human review is still needed before implementation begins.
