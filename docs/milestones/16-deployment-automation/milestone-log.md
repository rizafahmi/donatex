# Milestone 16 — Deployment automation

Issue: [#37](https://github.com/rizafahmi/notable/issues/37) — set up better deployment automation.

## Starting state (found, not assumed)

Verified against `origin/main` (`b1d447e`).

- [ADR-019](../../decisions/ADR-019-deployment-strategy-gcp-free-tier-releases.md) already settled the runtime shape: single Linux VM, `mix release`, `systemd`, a `current` symlink for rollback, SQLite as a file at `DATABASE_PATH`, no containers.
- `docs/OPERATIONS.md` held a manual checklist plus an **example** systemd unit and directory layout. The example values (`/opt/notable/current`, `/etc/notable/notable.env`, user `notable`) were illustrative, not verified facts about the real machine.
- `lib/notable/release.ex`, `rel/overlays/bin/migrate`, and `rel/overlays/bin/server` existed and were correct.
- `.github/workflows/ci.yml` ran `mix ci` plus the OpenCV QR-decode tests. It never deployed.
- The app was already live on a VM serving real traffic and real payments.

What ADR-019 did **not** settle: where the release gets built, and what triggers a deploy.
The manual checklist told operators to run `MIX_ENV=prod mix release` on the VM itself.

## Constraints this milestone worked under

No credentials for the live machine, and none were sought.
Nothing here was run against the real host: no SSH, no smoke test, no deploy.
Every behavioural claim below comes from the sandboxed test suite, `actionlint`, `shellcheck`, and `mix ci`.

## Approach

### Build in CI, ship the artifact

Recorded as [ADR-025](../../decisions/ADR-025-build-releases-in-github-actions.md).
A GCP free-tier `e2-micro` has 1 GB of RAM shared with the running BEAM; compiling there competes with the process that is currently taking payments.
The release is therefore built on `ubuntu-latest` with the Elixir 1.18.x / OTP 27 pair `ci.yml` already pins, tarred, and `scp`ed to the VM.
ERTS ships inside the release, so the VM no longer needs Erlang or Elixir at all.

### Logic in scripts, not in YAML

Inline YAML cannot be unit tested, and the properties that matter here are precisely the ones that need tests.
So the deploy is two bash scripts the workflows call in thin steps:

- `scripts/deploy/remote_deploy.sh` — runs on the VM. Subcommands `activate`, `rollback`, `prune-plan`.
- `scripts/deploy/ssh_deploy.sh` — runs on the runner. Uploads and invokes the above over SSH.

### Testing a deploy without a machine to deploy to

`test/support/deploy_sandbox.ex` builds a throwaway deploy root, fake release tarballs, and `sudo` / `systemctl` / `systemd-run` / `chown` / `ssh` / `scp` stubs that all append to one ordered log.

The trick that makes *ordering* assertable rather than merely "each step happened": every stub records the `current` symlink target at the moment it runs.
So a log line reading

```
migrate id=<new> current=<old>
```

is direct evidence that migrations ran before the swap, and

```
systemctl restart notable.service current=<new>
```

is direct evidence the swap preceded the restart.
No test inspects the script's source; they all drive the real script.

## Design decisions worth recording

### Rollback target selection

The rollback target is **the newest release strictly older than the current one**, not "the newest release that is not current".

The obvious rule ping-pongs: after rolling R3 → R2, "newest that is not current" selects R3 again and rolls forward.
The strictly-older rule walks R3 → R2 → R1 monotonically. Pinned by a test that rolls back twice.

This makes the `<UTC timestamp>-<short sha>` release id format load-bearing rather than cosmetic: reverse lexicographic sort has to equal reverse chronological sort for the rule to be correct.

### Migrations run through `systemd-run`

The alternative — the deploy script sourcing `DEPLOY_ENV_FILE` — would pull live secrets into the deploy process and require the deploy user to read a root-owned secrets file.

Instead the script passes `--property=EnvironmentFile=$DEPLOY_ENV_FILE` to `systemd-run` and lets systemd apply it, exactly as it does for the service.
The secrets never enter the script's process.
When the deploy user can read that file, the script also looks up the non-secret `DATABASE_PATH` line and aborts on disagreement with `DEPLOY_DATABASE_PATH`.
Under the recommended permissions that read usually fails, so the cross-check is opportunistic rather than a guarantee.
The guaranteed database guards need no env read: preflight refuses a database inside `DEPLOY_ROOT`, and the pruner refuses any candidate that contains or is contained by the database or its companions.

The honest cost, written into `docs/OPERATIONS.md` rather than glossed: granting `systemd-run` via sudoers is root-equivalent, so the deploy key is a root credential on that box however the sudoers line is phrased.

### Three independent guards on the database

The requirement was that pruning can never reach the SQLite file or its `-wal` / `-shm` companions. Layered, so no single refactor can defeat it:

1. Preflight refuses to `activate` or `rollback` at all when the database or either companion resolves inside `DEPLOY_ROOT`.
2. `classify_releases` emits `protect … contains-database` for any candidate that contains, or is contained by, a guarded path, and never emits `remove` for it.
3. The single `rm -rf` re-checks parent directory, symlink status, directory-ness, and the database guard immediately before running.

`prune-plan` exists so guard (2) is directly assertable: it runs the same classifier the destructive prune consumes and prints one verdict per entry without deleting anything.
It is also a genuinely useful operator command.
A test traps a database inside a release directory and asserts the classifier protects it; another does the same with only the `-wal` companion present.

### Atomic symlink swap across two userlands

`ln -sfn` is not atomic — it unlinks then links.
The atomic idiom is to create a temporary symlink and `rename(2)` it over the target, which needs an explicit "do not follow the destination symlink" flag: GNU spells it `mv -T`, BSD/macOS spells it `mv -h`.
The script tries both and verifies the resulting `readlink`, so it behaves identically on the Ubuntu target and on the macOS machine the tests run on.

### Automatic rollback on a failed start

Not asked for, but leaving a payments box down after a failed deploy is worse than the added complexity.
If the unit does not become active after the restart, the deploy re-points `current` at the previous release, restarts, and exits non-zero.
It reuses the same swap-and-restart path as manual rollback.

### `workflow_dispatch` only

No `push` trigger on the deploy workflow. `.github/workflows/deploy.yml` carries an in-file comment naming the exact edit that enables deploy-on-merge, and `docs/OPERATIONS.md` documents the same switch.

One caveat is documented rather than silently accepted: CI and Deploy are separate workflows, so a `push`-triggered deploy would start *alongside* `mix ci`, not after it.

## Verification

Everything below was run in this worktree. Nothing was run against the live host.

- `mix ci`: 393 tests, 0 failures; `credo --strict` clean; dialyzer 0 errors; `ex_dna` 0 clones; `reach.check --arch --smells` OK.
- `actionlint` 1.7.12 on `deploy.yml`, `rollback.yml`, `ci.yml`: clean. The binary is not installed on this machine; it was fetched from the upstream release page into a scratch directory for the run and is not vendored into the repo.
- `shellcheck` 0.10.0 on both deploy scripts: clean.
- 58 deploy-specific tests across three files.

What is **not** verified, and cannot be from here:

- That the real VM's layout matches `DEPLOY_ROOT` / `DEPLOY_ENV_FILE` / unit name as configured. Those are repository variables precisely because this side does not know them.
- That the deploy user has the sudoers grants the scripts need.
- That `systemd-run --wait --collect --pipe` behaves as expected on the target's systemd version.
- Any end-to-end run. The first real dispatch is the captain's, after they create the secrets.

## Files

| Path | Role |
| --- | --- |
| `.github/workflows/deploy.yml` | Build on the runner, ship, activate. `workflow_dispatch` only. |
| `.github/workflows/rollback.yml` | Dispatchable rollback. Builds nothing. |
| `scripts/deploy/remote_deploy.sh` | On-VM: activate / rollback / prune-plan. |
| `scripts/deploy/ssh_deploy.sh` | On-runner: upload and invoke over SSH. |
| `test/support/deploy_sandbox.ex` | Sandbox filesystem plus stubbed privileged tooling. |
| `test/notable/deploy/remote_deploy_test.exs` | Ordering, rollback selection, retention, database safety. |
| `test/notable/deploy/ssh_deploy_test.exs` | SSH invocation composition, host key verification, key hygiene. |
| `test/notable/deploy/deploy_workflow_test.exs` | Trigger shape, no hardcoded host, CI untouched, docs in sync. |
| `docs/decisions/ADR-025-build-releases-in-github-actions.md` | Build-in-CI and manual-trigger rationale. |
| `docs/OPERATIONS.md` | Automated flow as the primary path; manual retained as fallback. |

## Next steps for the captain

1. Create the four secrets and the repository variables listed in `docs/OPERATIONS.md` under [Required Secrets And Variables](../../OPERATIONS.md#required-secrets-and-variables).
2. Grant the deploy user the sudoers entries in the same document, or switch to `DEPLOY_SSH_USER=root` with `DEPLOY_PRIVILEGED_CMD=""`.
3. Dispatch **Actions → Deploy** once and watch it. The first run creates `releases/` and `current` from scratch, so there is no rollback target yet.
4. Once satisfied, consider adding a required reviewer to the `production` environment, then make the deploy-on-merge edit.
