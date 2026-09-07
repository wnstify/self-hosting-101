# Getting started

Start with the [episode index](episodes/README.md) to follow the series, or choose a guide from the [topic list](README.md#browse-by-topic). You can use a written guide without watching its video.

## Before following a guide

1. Read its outcome, prerequisites, and tested configuration. Confirm that its hardware, software, and network assumptions fit your setup.
2. Read the full procedure, including verification and recovery, before making changes.
3. Use your own server details and public SSH key. Example addresses and configuration files are placeholders.
4. Check where each command runs. A workstation command and a command for a remote server can have very different effects.
5. Complete the verification steps before moving to another guide. Keep deployment details and logs private.

For the first guide, you need a Hetzner dedicated server that matches the documented installation scope, access to its provider panel, and an SSH key. Installing Proxmox erases the two selected disks. The guide includes the disk checks and approval step.

## Available now

[Proxmox on Hetzner](infrastructure/proxmox-hetzner/README.md) is the first guide. Its [test record](infrastructure/proxmox-hetzner/tested-configuration.md) describes the configuration that was tested and the checks that passed.

Later guides will list their own prerequisites and link to earlier topics when needed. The [roadmap](ROADMAP.md) contains ideas, not instructions to run.

## Choose how to work

Follow the commands yourself, or give an agent the [starting prompt](USING-AI.md). Both paths use the same guide and scripts. Keep control of credentials and approve destructive work against the actual target.

## Keep track of updates

Check the current guide before reusing commands from a video or PDF. When following a particular recording, use the repository commit or tag listed with that episode, if available. Review any current correction notice before running older instructions.

Guide status and video status are separate. A guide can be available while its video is still being recorded.
