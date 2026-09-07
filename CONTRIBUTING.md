# Contributing and repository layout

Keep each topic usable on its own and link to prerequisites. Add new guides as the series grows; use the roadmap for topics that have no content yet.

## Where files belong

Use lowercase folder names with hyphens, such as `infrastructure/proxmox-hetzner`. Choose the category that best describes the guide's main outcome. Link from other category indexes if useful. Keep episode numbers in the episode index.

```text
category/topic/
  README.md
  AGENTS.md                  # Only when the workflow needs specific rules
  tested-configuration.md
  verification.md            # Optional split from a longer guide
  images/
  tests/
  materials/
    README.md                # Index of available files and their revisions
    documents/               # Editable handouts and supplementary documents
    slides/                  # Editable slide decks or slide source
    exports/                 # Published PDFs and other downloads
  ...scripts and example configuration
```

Create optional directories when they contain actual material. Keep helpers in the layout their commands and tests expect. Move reusable code into a shared location only when multiple guides need it.

The root `skills/` directory holds agent workflows. Each skill must locate its companion topic directory and use the same scripts as the human guide. The root `records/` directory is git-ignored and holds private deployment evidence.

## Write a guide

Start with [the guide template](templates/guide-template.md) and use the [status conventions](ROADMAP.md#status-conventions). Explain the outcome, prerequisites, where commands run, and how to verify success. Include recovery and maintenance where they apply. Label unsupported or untested cases.

Keep security settings inside the procedure that needs them. Document exposed services, authentication, credentials, and backup requirements before declaring an application ready. Link to related guides for longer explanations.

Use documentation addresses and placeholder values in examples. Publish sanitized results only. Keep secrets, private keys, populated deployment configuration, and raw logs out of tracked files and teaching materials.

## Add documents and slides

Use [the materials index template](templates/materials-template.md) to list each available file or public link, its format, and its source revision. Add a short description so viewers know whether it is a checklist, a handout, or a presentation.

Keep editable document sources under `materials/documents/`, slide sources under `materials/slides/`, and downloadable exports under `materials/exports/`. Markdown supplementary guides can live in `documents/` too. Link shared instructions instead of maintaining separate command lists in each format.

Use descriptive filenames such as `installation-checklist.md`, `proxmox-overview.pptx`, and `installation-checklist.pdf`. Record the export date and source commit in the index and, where practical, inside the export. Link large downloads and video files from a release or their publishing platform instead of storing them in Git.

Inspect exported pages and slides before adding them. Check readability and links, and remove private information from screenshots and document metadata. List an item as available only when its file or public link exists.

## Update a published topic

1. Edit the maintained guide and relevant helpers together. Preserve documented safety checks.
2. Run the local checks appropriate to the change and check relative links. Record live validation separately; a documentation edit does not retest a deployment.
3. Add a dated correction note if a published video or download now gives outdated commands or safety advice. State which revision is affected and what readers should do.
4. Update affected documents and exports, or label them as matching an older revision. Preserve the recording revision in the episode index.
5. Update the category index, root topic list, roadmap, and episode entry when availability changes.

Keep test dates tied to actual validation. Changing a guide's wording or location does not change its last deployment test date.

## Check the current Proxmox guide

These local tests require Python 3.11 or later, Bash, and `ssh-keygen`. Run on the workstation from the repository root:

```text
python infrastructure/proxmox-hetzner/tests/test-firmware-policy.py
python infrastructure/proxmox-hetzner/tests/test-answer-credentials.py
```

Use Bash syntax checks for the shell scripts. The local Python tests check launcher refusals and SSH public-key validation without disks or server access. The credential tests use synthetic public keys and a mocked password hash. The live preflight test has separate prerequisites in the [installation guide](infrastructure/proxmox-hetzner/README.md) and is not a local documentation check.
