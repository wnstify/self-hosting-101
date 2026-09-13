# Verification runner

`verify.py` checks both flavors of every recipe. It needs Docker with Compose, Python 3 with PyYAML, and a `dhi.io` login for Docker Hardened Images when DHI recipes are selected. Run it from anywhere; the paths below assume the repository root.

## Commands

```sh
python3 applications/docker-recipes/verification/verify.py static
python3 applications/docker-recipes/verification/verify.py run
python3 applications/docker-recipes/verification/verify.py run --app n8n --flavor dhi
python3 applications/docker-recipes/verification/verify.py run --changed origin/main --jobs 2
python3 applications/docker-recipes/verification/verify.py list
```

`static` renders every Compose file with its environment example and fails on a missing digest pin, a long-running service without a healthcheck, a port published outside loopback that the spec does not allow, an empty variable that nothing can fill, a service list that differs between flavors, or a missing spec. It takes seconds and starts nothing.

`run` deploys each selected recipe and records these steps in order. The first failed step ends the run for that recipe.

1. Copy the recipe to a working directory and build `.env`. Every `# Generate: <command>` comment runs, `values` from the spec fill the rest, and `derive` lines compute dependent values. Host ports get free port numbers, and URLs that embed the old port are rewritten.
2. Run `prepare` and require exit code 0.
3. `up --wait` within the spec timeout.
4. Every service with a restart policy is running and healthy, every one-shot job exited 0, and no container has restarted.
5. GET the probe path and accept the listed status codes.
6. Scan the logs for error markers, minus the spec's allow list.
7. Stop, then `up --wait` again, and repeat steps 4 to 6 on the post-restart log segment.
8. Run the functional hook after step 5 and again after step 7 when the spec names one. No spec defines a hook yet.

`--changed REF` limits the matrix to applications whose recipe or spec differs from REF. `--jobs N` runs recipes in parallel, and the scheduler keeps the summed container memory limits of running recipes under `--memory` megabytes, which defaults to three quarters of the host RAM. `--keep` leaves failed deployments in the working directory for inspection.

Results go to `~/.cache/docker-recipes-verify/results/<app>-<flavor>/` with a `result.json` per recipe, the logs each step examined, and a `summary.md` table at the top. The exit code is nonzero when any recipe fails.

## Adding an application

1. Add `standard/<app>` and `dhi/<app>`, each with `compose.yaml` and `.env.example`. Put a `# Generate: <command>` comment above every empty secret.
2. Add `verification/apps/<app>.yaml`. The [spec README](apps/README.md) lists every key. A probe path and status are usually enough.
3. Run `static`, then `run --app <app>`. Add `allow` entries only for log lines you have read and can explain in the `why` field.

## Log scanning

A log line counts as an error when it contains `ERROR`, `ERRO`, `FATAL`, `CRITICAL`, `PANIC`, `Traceback`, `panic:`, `level=error`, `"level":"error"`, `[error]`, or `[crit]`. Warnings do not fail a run. Startup noise from dependency images, such as the Redis overcommit warning, is a warning and passes without an allow entry.

## Host notes

The working directory must be on disk, not tmpfs. Nextcloud fails to install on a RAM-backed mount. The runner deletes its own working copies under `--workdir` after each recipe; `--keep` leaves failed ones in place. Rootless Docker maps container owners to subordinate ids, so it deletes them through a container rather than with a plain remove.
