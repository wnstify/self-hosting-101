# Start here

You can use any written guide without watching its video. Each guide opens with its status, what it builds, and the configuration it was tested on. Check those against your own hardware and network before you run anything.

1. Read the whole procedure first, including verification and recovery. Steps that erase disks say so before the command.
2. Note where each command runs. Every block is labeled: workstation, Rescue, the temporary QEMU guest, or the physical Proxmox host. A server command run on your workstation can do damage, and the other way round.
3. Replace every placeholder. Addresses such as `192.0.2.10` and names such as `example.com` are documentation values. Use your own server details and your own public SSH key.
4. Finish the verification steps before you move on. Keep addresses, disk serials, logs, and credentials out of anything you publish.
5. You are the operator. The scripts stop on what they can detect, such as a wrong disk serial or a UEFI boot, and on nothing else. A mirror is not a backup, and nothing here replaces one.

For the first guide you need a bare-metal server that meets the guide's requirements list, access to the provider's panel, and an SSH key. Virtual servers do not work. Hetzner dedicated servers are the tested and recommended option; see the [tested configuration](infrastructure/proxmox-hetzner/tested-configuration.md).

## Guides and videos change separately

A guide can be available while its video is still being recorded. When a guide changes after a recording, the [episode index](episodes/README.md) keeps the commit or tag used on screen, and the guide gets a dated correction note if commands or safety advice changed. Check the current guide before reusing commands from a video or a PDF.

## Working with an AI agent

You can type the commands yourself or hand the guide to an agent with the [starting prompt](USING-AI.md). Both paths use the same scripts and checks. You keep the credentials, and you approve destructive work against the exact target.
