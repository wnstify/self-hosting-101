# Guide title

One or two sentences: what this guide installs or changes, and on what. Copy this template into the topic directory and remove the author instructions before publication. The Proxmox guide is the reference for the shape below.

Add a navigation line here linking the category index, the episode index, and the topic's materials index, with paths relative to the topic directory.

| Detail | Value |
|---|---|
| Status | Draft |
| Video | Planned |
| Last live test | Not yet, or the date and hardware with a link to the tested configuration |
| Materials | None yet |

If the scripts changed after the last live test, say so here and list the changes in the tested configuration.

## What this guide does

State the resulting setup and its limits. Name the tested hardware and what needs its own validation. Put every destructive step and every hard requirement in bold sentences here, with the reason when one exists. Say where workstation commands expect to run.

## 1. First step

Write ordered steps. Name the machine before each command block: workstation, Rescue, temporary installed QEMU guest, or physical host. Give the expected result and the failure condition after the block. Reference shared scripts instead of restating their logic.

## 2. Next step

Keep going. Split verification into `verification.md` when the guide gets long, and link it from the last step.

## Verify the result

Checks with expected results and failure conditions. Cover service health, access restrictions, and persistence across a restart. Separate observed results from assumptions.

## Recovery

How to inspect a failure and return to a known state. If a step cannot be undone, say so before the step. Do not prescribe automatic destructive retries. If no tested repair exists, say that instead of guessing.

## Maintenance and backups

Updates, data that needs backup, and how to verify a restore. Link separate procedures when they exist. Name maintenance work outside this guide's scope.

## Agent instructions

Point to the root AGENTS.md, the topic AGENTS.md if there is one, and the skill. People and agents use the same scripts and checks.

## References

Official sources supporting the procedure. Dated correction notes go here when a published recording or export needs one.
