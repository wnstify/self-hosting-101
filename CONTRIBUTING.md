# Contributing and repository layout

Keep each topic usable on its own and link to prerequisites. Topics without content stay in the roadmap until a draft exists.

## Where files belong

Use lowercase folder names with hyphens, such as `infrastructure/proxmox-hetzner`. Choose the category that best describes the guide's main outcome. Link from other category indexes if useful. Keep episode numbers in the episode index.

```text
category/topic/
  README.md                  # The guide: status table, overview, numbered steps
  AGENTS.md                  # Only when the workflow needs rules beyond the root AGENTS.md
  tested-configuration.md    # What was tested, what changed since, what was not tested
  verification.md            # Split out when the guide gets long
  boot-recovery.md           # Or another recovery or inspection document, when one exists
  images/
  tests/
  materials/
    README.md                # Index of existing files and their revisions
    documents/               # Editable handouts and supplementary documents
    slides/                  # Editable slide decks or slide source
    exports/                 # Published PDFs and other downloads
  ...scripts and example configuration
```

Create optional directories only when there is something to put in them. Keep helpers in the layout their commands and tests expect. Move reusable code into a shared location only when more than one guide needs it.

The root `skills/` directory holds agent checklists. Each skill must locate its companion topic directory and use the same scripts as the guide. The root `records/` directory is git-ignored and holds private deployment evidence.

## Status conventions

Guides are `Planned`, `Draft`, `Available`, or `Archived`. `Planned` means no guide exists yet. `Draft` means work has started but the guide is not ready to follow. `Available` means it is ready within its documented scope. `Archived` guides say why they are no longer maintained and link to a replacement when one exists.

Videos are `Planned`, `Recording`, or `Published`. Add a YouTube link only after publication.

Each guide opens with a table showing its status, video status, last live test, and materials. The tested configuration file holds the detail: what passed, what changed since, and what was not tested. Documents and slides count as available only when their file or public link exists.

## Write a guide

Start with [the guide template](templates/guide-template.md). Explain the outcome, prerequisites, where commands run, and how to verify success. Include recovery and maintenance where they apply. Label unsupported or untested cases.

Keep security settings inside the procedure that needs them. Document exposed services, authentication, credentials, and backup requirements before declaring an application ready. Link to related guides for longer explanations.

Use documentation addresses and placeholder values in examples. Publish sanitized results only. Keep secrets, private keys, populated deployment configuration, and raw logs out of tracked files and teaching materials.

## Add documents and slides

Use [the materials index template](templates/materials-template.md) to list each file or public link, its format, and its source revision. Add a short description so viewers know whether it is a checklist, a handout, or a presentation.

Keep editable document sources under `materials/documents/`, slide sources under `materials/slides/`, and downloadable exports under `materials/exports/`. Markdown supplementary guides can live in `documents/` too. Link to the shared instructions instead of maintaining separate command lists in each format.

Use descriptive filenames such as `installation-checklist.md`, `proxmox-overview.pptx`, and `installation-checklist.pdf`. Record the export date and source commit in the index and, where practical, inside the export. Link large downloads and video files from a release or their publishing platform instead of storing them in Git.

Inspect exported pages and slides before adding them. Check readability and links, and remove private information from screenshots and document metadata.

## Update a published topic

1. Edit the guide and its helpers together. Preserve documented safety checks.
2. Run the local checks for the change and check relative links. A documentation edit does not retest a deployment; record live validation separately.
3. Add a dated correction note if a published video or download now gives outdated commands or safety advice. State which revision is affected and what readers should do.
4. Update affected documents and exports, or label them as matching an older revision. Preserve the recording revision in the episode index.
5. Update the category index, root topic list, roadmap, and episode entry when availability changes.

A test date belongs to the validation it records. Changing a guide's wording or location does not change its last live test date; add the change to the tested configuration's "changes since" list instead.

## Check the current Proxmox guide

These local tests need Python 3.11 or later, Bash, and `ssh-keygen`. They touch no disks and no server. Run them on the workstation from the repository root:

```text
python infrastructure/proxmox-hetzner/tests/test-firmware-policy.py
python infrastructure/proxmox-hetzner/tests/test-answer-credentials.py
```

The firmware test checks that both launchers refuse UEFI and missing or invalid firmware modes. The credential test checks SSH public-key validation with synthetic keys and a mocked password hash. Syntax-check the shell scripts in Git Bash:

```text
for script in infrastructure/proxmox-hetzner/*.sh infrastructure/proxmox-hetzner/tests/*.sh; do bash -n "$script"; done
```

The live refusal test, `tests/preflight-refusals.sh`, runs in Rescue and is described in the [installation guide](infrastructure/proxmox-hetzner/README.md#agent-instructions).
