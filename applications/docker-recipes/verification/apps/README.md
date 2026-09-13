# Application test specs

One YAML file per application, named after its folder. Both flavors share the file. Keys under `standard:` or `dhi:` override the top level for that flavor only.

```yaml
probe:
  path: /                 # GET http://127.0.0.1:$PORT<path>. Default: /
  status: [200, 302]      # Accepted HTTP codes. Default: any code below 500.
  contains: "Sign in"     # Optional substring the body must contain.
  port: ADGUARD_PORT      # Optional: env variable with the port to probe. Default: PORT.
timeout: 300              # Seconds allowed for `up --wait`. Default: 300.
ports: [PORT, SYNC_PORT]  # Env variables holding host ports the runner reassigns.
                          # Default: PORT and every variable ending in _PORT.
values:                   # Filler for empty variables that have no Generate comment.
  ADMIN_PASSWORD: generate   # The word generate means a random hex value.
  SMTP_PASSWORD: ""          # Anything else is used as written.
set:                      # Replace any variable, empty or not, after ports are assigned.
  SITE_URL: http://127.0.0.1:${PORT}   # ${VAR} expands against the generated .env.
derive:                   # Bash run after generation with every .env value exported.
  - 'echo "HASH=$(printf %s "$ADMIN_PASSWORD" | sha256sum | cut -c1-64)"'
                          # Each stdout line KEY=VALUE is merged into .env.
                          # cut drops sha256sum's trailing filename field.
allow:                    # Log lines containing `text` are not counted as errors.
  - text: vm.overcommit_memory
    why: Redis warns on hosts without overcommit. Recorded in batch-a.md.
functional: functional/qbittorrent.sh   # Optional hook, relative to verification/. No spec defines one yet and the directory does not exist.
public_ports: [syncthing]  # Services allowed to publish ports on all interfaces.
port_ranges: [[VOICE_UDP_START, VOICE_UDP_END]]  # Variable pairs that must stay a range.
```

The runner reads `# Generate: <command>` and `# Generate with: <command>` comments in `.env.example` and runs the command for the empty variable below it. Variables that are empty with no Generate comment must appear in `values` or come out of `derive`, or the static check fails.

The functional hook receives the deployment directory as the working directory, the `.env` values in its environment, and `PHASE` set to `initial` or `restart`. Exit code 0 passes.
