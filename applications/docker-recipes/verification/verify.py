#!/usr/bin/env python3
"""Verify the standard and DHI Compose recipes.

    verify.py static                 render every recipe and check pins, specs, ports
    verify.py run [filters]          start recipes, check health, probe, logs, restart
    verify.py list                   print the recipe matrix

Runtime results land in --results (default ~/.cache/docker-recipes-verify/results).
"""

import argparse
import concurrent.futures
import datetime as dt
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
SPECS = ROOT / 'verification' / 'apps'
FLAVORS = ('standard', 'dhi')
LOG_ERROR = re.compile(r'\b(ERROR|ERRO|FATAL|CRITICAL|PANIC|Traceback)\b|panic:|level=error|"level":\s*"error"|\[error\]|\[crit\]')
GENERATE = re.compile(r'^#.*\bGenerate(?: with)?: (.+)$')
ASSIGN = re.compile(r"^([A-Z][A-Z0-9_]*)=(.*)$")
DIGEST = re.compile(r'@sha256:[0-9a-f]{64}$')
PORT_VAR = re.compile(r'^(PORT|[A-Z0-9_]+_PORT)$')
DEFAULT_TIMEOUT = 300


def sh(args, cwd=None, env=None, timeout=None, check=False):
    result = subprocess.run(args, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)
    if check and result.returncode:
        raise RuntimeError(f"{' '.join(map(str, args))}\n{result.stdout}{result.stderr}".strip())
    return result


def compose_config(directory, env_file):
    # The wildcard profile keeps prepare and other profiled services in the rendered output.
    result = sh(['docker', 'compose', '--profile', '*', '--env-file', str(env_file),
                 '-f', str(directory / 'compose.yaml'), 'config', '--format', 'json'], cwd=directory, check=True)
    return json.loads(result.stdout)


def quote(value):
    if value and not re.search(r'[\s$#\'"\\]', value):
        return value
    return "'" + value.replace("'", "'\\''") + "'"


def read_env(path):
    values = {}
    for line in path.read_text().splitlines():
        match = ASSIGN.match(line)
        if match:
            values[match.group(1)] = match.group(2).strip("'\"")
    return values


def load_spec(app, flavor):
    path = SPECS / f'{app}.yaml'
    if not path.is_file():
        return None
    spec = yaml.safe_load(path.read_text()) or {}
    override = spec.pop(flavor, None) or {}
    for other in FLAVORS:
        spec.pop(other, None)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(spec.get(key), dict):
            spec[key] = {**spec[key], **value}
        elif isinstance(value, list) and isinstance(spec.get(key), list):
            spec[key] = spec[key] + value
        else:
            spec[key] = value
    return spec


def apps():
    found = {f: sorted(p.name for p in (ROOT / f).iterdir() if p.is_dir()) for f in FLAVORS}
    return found


def matrix(args):
    found = apps()
    names = sorted(set(found['standard']) | set(found['dhi']))
    if getattr(args, 'changed', None):
        # --relative reports paths from this directory, wherever it sits in the repository.
        diff = sh(['git', 'diff', '--name-only', '--relative', args.changed, '--', '.'], cwd=ROOT, check=True).stdout
        touched = set()
        for line in diff.splitlines():
            parts = line.split('/')
            if len(parts) >= 3 and parts[0] in FLAVORS:
                touched.add(parts[1])
            elif len(parts) == 3 and parts[:2] == ['verification', 'apps']:
                touched.add(Path(parts[2]).stem)
        names = [n for n in names if n in touched]
    if getattr(args, 'app', None):
        names = [n for n in names if n in args.app]
    flavors = [f for f in FLAVORS if not getattr(args, 'flavor', None) or f in args.flavor]
    return [(n, f) for n in names for f in flavors if n in found[f]]


# --- static -----------------------------------------------------------------

def empty_without_generate(env_path):
    lines = env_path.read_text().splitlines()
    missing = []
    prev = ''
    for line in lines:
        match = ASSIGN.match(line)
        if match and match.group(2).strip("'\"") == '' and not GENERATE.match(prev):
            missing.append(match.group(1))
        if not line.startswith('#') or GENERATE.match(line):
            prev = line
    return missing


def static(args):
    errors = []
    found = apps()
    if found['standard'] != found['dhi']:
        errors.append('standard and dhi application folders differ: '
                      f"{sorted(set(found['standard']) ^ set(found['dhi']))}")
    services_by_app = {}
    rendered = 0
    fallbacks = []
    for app, flavor in matrix(args):
        directory = ROOT / flavor / app
        label = f'{flavor}/{app}'
        env_path = directory / '.env.example'
        if not env_path.is_file():
            errors.append(f'{label}: missing .env.example')
            continue
        spec = load_spec(app, flavor)
        if spec is None:
            errors.append(f'{label}: missing verification/apps/{app}.yaml')
            spec = {}
        try:
            config = compose_config(directory, env_path)
        except RuntimeError as exc:
            errors.append(f'{label}: compose config failed: {exc}')
            continue
        rendered += 1
        services = config['services']
        services_by_app.setdefault(app, {})[flavor] = set(services)
        hardened = False
        public_ok = set(spec.get('public_ports') or [])
        for name, service in services.items():
            image = service.get('image', '')
            if not DIGEST.search(image):
                errors.append(f'{label}/{name}: image lacks a SHA-256 digest pin')
            if image.startswith('dhi.io/'):
                hardened = True
                if flavor == 'standard':
                    errors.append(f'{label}/{name}: standard image points to DHI')
            if service.get('restart', 'no') != 'no':
                health = service.get('healthcheck') or {}
                if not health.get('test') or health.get('disable') or health['test'][0] == 'NONE':
                    errors.append(f'{label}/{name}: missing enabled healthcheck')
            for port in service.get('ports') or []:
                if port.get('host_ip') != '127.0.0.1' and name not in public_ok:
                    errors.append(f'{label}/{name}: port {port.get("published")} is not bound to '
                                  '127.0.0.1 and the service is not listed under public_ports')
        if flavor == 'dhi' and not hardened:
            fallbacks.append(app)
        covered = set(spec.get('values') or {})
        for line in spec.get('derive') or []:
            covered.update(re.findall(r'\b([A-Z][A-Z0-9_]*)=', line))
        for var in empty_without_generate(env_path):
            if var not in covered:
                errors.append(f'{label}: {var} is empty with no Generate comment and no spec value')
        if 'PORT' not in read_env(env_path) and not (spec.get('probe') or {}).get('port'):
            errors.append(f'{label}: .env.example has no PORT and the spec names no probe port')
    for app, flavors in services_by_app.items():
        if len(flavors) == 2 and flavors['standard'] != flavors['dhi']:
            errors.append(f'{app}: service names differ between flavors: '
                          f"{sorted(flavors['standard'] ^ flavors['dhi'])}")
    print(f'Rendered {rendered} Compose configurations.')
    print('DHI folders using only upstream images: ' + ', '.join(sorted(fallbacks)))
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print('Image pins, paired folders, healthchecks, port bindings, and specs pass.')
    return 0


# --- runtime ----------------------------------------------------------------

class PortPool:
    def __init__(self):
        self.lock = threading.Lock()
        self.taken = set()

    def free_port(self):
        with self.lock:
            while True:
                with socket.socket() as sock:
                    sock.bind(('127.0.0.1', 0))
                    port = sock.getsockname()[1]
                if port not in self.taken:
                    self.taken.add(port)
                    return port

    def free_range(self, size):
        with self.lock:
            start = 40000 + secrets.randbelow(20000)
            while any(p in self.taken for p in range(start, start + size)):
                start = 40000 + secrets.randbelow(20000)
            self.taken.update(range(start, start + size))
            return start


PORTS = PortPool()


class Run:
    def __init__(self, app, flavor, args):
        self.app, self.flavor, self.args = app, flavor, args
        self.spec = load_spec(app, flavor) or {}
        self.name = f'{app}-{flavor}'
        self.project = f'vt-{self.name}'
        self.source = ROOT / flavor / app
        self.workdir = Path(args.workdir).expanduser() / self.name
        self.results = Path(args.results).expanduser() / self.name
        self.steps = []
        self.env = {}
        self.timeout = int(self.spec.get('timeout') or DEFAULT_TIMEOUT)
        self.started = None

    # -- helpers
    def step(self, name, ok, detail=''):
        self.steps.append({'step': name, 'ok': bool(ok), 'detail': detail.strip()[:4000]})
        mark = 'ok ' if ok else 'FAIL'
        print(f'[{self.name}] {mark} {name}' + (f': {detail.strip().splitlines()[0][:120]}' if detail and not ok else ''), flush=True)
        if not ok:
            raise StepFailed(name)

    def compose(self, *cmd, timeout=None, check=True):
        return sh(['docker', 'compose', '-p', self.project, *cmd], cwd=self.workdir, timeout=timeout, check=check)

    def save(self, name, text):
        self.results.mkdir(parents=True, exist_ok=True)
        (self.results / name).write_text(text)

    # -- phases
    def build_env(self):
        lines = (self.source / '.env.example').read_text().splitlines()
        env = os.environ.copy()
        out = []
        prev = ''
        generated = {}
        for line in lines:
            match = ASSIGN.match(line)
            if match:
                key, value = match.group(1), match.group(2).strip("'\"")
                gen = GENERATE.match(prev)
                changed = True
                if value == '' and gen:
                    value = subprocess.run(['bash', '-c', gen.group(1)], capture_output=True, text=True,
                                           env=env, check=True).stdout.strip()
                    if not value:
                        raise RuntimeError(f'Generate command for {key} produced nothing')
                elif value == '' and key in (self.spec.get('values') or {}):
                    filler = self.spec['values'][key]
                    value = secrets.token_hex(16) if filler == 'generate' else str(filler)
                else:
                    changed = False
                generated[key] = value
                env[key] = value
                # Untouched lines stay verbatim so Compose still expands ${VAR} references in them.
                out.append(f'{key}={quote(value)}' if changed else line)
            else:
                out.append(line)
            if not line.startswith('#') or GENERATE.match(line):
                prev = line
        for snippet in self.spec.get('derive') or []:
            result = subprocess.run(['bash', '-c', snippet], capture_output=True, text=True, env=env, check=True)
            for dline in result.stdout.splitlines():
                dm = ASSIGN.match(dline)
                if dm:
                    value = dm.group(2).strip()
                    if len(value) > 1 and value[0] == value[-1] and value[0] in '\'"':
                        value = value[1:-1]
                    generated[dm.group(1)] = value
                    env[dm.group(1)] = value
                    out = [f'{dm.group(1)}={quote(value)}' if o.startswith(dm.group(1) + '=') else o for o in out]
        # Reassign host ports so parallel runs and leftovers never collide.
        port_vars = self.spec.get('ports') or [k for k in generated if PORT_VAR.match(k)]
        old_ports = {}
        ranges = self.spec.get('port_ranges') or []
        for start_var, end_var in ranges:
            size = int(generated[end_var]) - int(generated[start_var]) + 1
            base = PORTS.free_range(size)
            old_ports[start_var] = (generated[start_var], str(base))
            old_ports[end_var] = (generated[end_var], str(base + size - 1))
        for key in port_vars:
            if key in generated and key not in old_ports:
                old_ports[key] = (generated[key], str(PORTS.free_port()))
        final = []
        for o in out:
            m = ASSIGN.match(o)
            if m and m.group(1) in old_ports:
                o = f'{m.group(1)}={old_ports[m.group(1)][1]}'
                generated[m.group(1)] = old_ports[m.group(1)][1]
            elif m and any(f'127.0.0.1:{old}' in m.group(2) for old, _ in old_ports.values()):
                value = generated[m.group(1)]
                for old, new in old_ports.values():
                    value = value.replace(f'127.0.0.1:{old}', f'127.0.0.1:{new}')
                o = f'{m.group(1)}={quote(value)}'
                generated[m.group(1)] = value
            final.append(o)
        # Spec overrides replace any value, with ${VAR} expanded against the generated set.
        for key, template in (self.spec.get('set') or {}).items():
            value = re.sub(r'\$\{([A-Z0-9_]+)\}', lambda m: generated.get(m.group(1), ''), str(template))
            generated[key] = value
            line = f'{key}={quote(value)}'
            final = [line if ASSIGN.match(o) and ASSIGN.match(o).group(1) == key else o for o in final]
            if line not in final:
                final.append(line)
        self.env = generated
        (self.workdir / '.env').write_text('\n'.join(final) + '\n')
        os.chmod(self.workdir / '.env', 0o600)
        empties = [k for k, v in generated.items() if v == '' and k not in (self.spec.get('values') or {})]
        if empties:
            raise RuntimeError(f'empty values after generation: {empties}')

    def prepare_workdir(self):
        self.cleanup(quiet=True)
        self.workdir.mkdir(parents=True)
        shutil.copy2(self.source / 'compose.yaml', self.workdir / 'compose.yaml')
        self.build_env()
        config = compose_config(self.workdir, self.workdir / '.env')
        self.services = config['services']
        self.prepare_image = next((s['image'] for n, s in self.services.items() if n == 'prepare'), None)

    def containers(self):
        result = self.compose('ps', '-a', '--format', 'json', check=False)
        text = result.stdout.strip()
        rows = json.loads(text) if text.startswith('[') else [json.loads(l) for l in text.splitlines() if l.strip()]
        ids = [row['ID'] for row in rows]
        if not ids:
            return []
        inspect = sh(['docker', 'inspect', *ids], check=True)
        return json.loads(inspect.stdout)

    def check_state(self, phase):
        problems = []
        seen = set()
        for c in self.containers():
            service = c['Config']['Labels'].get('com.docker.compose.service')
            seen.add(service)
            state = c['State']
            restart = self.services.get(service, {}).get('restart', 'no')
            if restart == 'no':
                if state['Status'] != 'exited' or state['ExitCode'] != 0:
                    problems.append(f'{service}: one-shot job status {state["Status"]} exit {state["ExitCode"]}')
                continue
            health = (state.get('Health') or {}).get('Status', 'none')
            if state['Status'] != 'running' or health != 'healthy':
                problems.append(f'{service}: {state["Status"]}, health {health}')
            if c.get('RestartCount', 0):
                problems.append(f'{service}: restarted {c["RestartCount"]} times')
        missing = [s for s, d in self.services.items() if s not in seen and s != 'prepare'
                   and not (d.get('profiles'))]
        if missing:
            problems.append(f'services never started: {missing}')
        self.step(f'{phase}: containers healthy', not problems, '\n'.join(problems))

    def probe(self, phase):
        spec = self.spec.get('probe') or {}
        port = self.env.get(spec.get('port', 'PORT'))
        url = f'http://127.0.0.1:{port}{spec.get("path", "/")}'
        accept = spec.get('status')
        deadline = time.time() + 60
        last = ''
        while time.time() < deadline:
            try:
                req = urllib.request.Request(url, headers={'User-Agent': 'docker-recipes-verify'})
                with urllib.request.urlopen(req, timeout=10) as resp:
                    code, body = resp.status, resp.read(65536).decode('utf-8', 'replace')
            except urllib.error.HTTPError as exc:
                code, body = exc.code, exc.read(65536).decode('utf-8', 'replace')
            except (urllib.error.URLError, socket.timeout, ConnectionError, OSError) as exc:
                last = f'{url}: {exc}'
                time.sleep(3)
                continue
            ok = code in accept if accept else code < 500
            if ok and spec.get('contains') and spec['contains'] not in body:
                ok, last = False, f'{url}: {code} but body lacks {spec["contains"]!r}'
            elif not ok:
                last = f'{url}: HTTP {code}'
            if ok:
                self.step(f'{phase}: probe {spec.get("path", "/")}', True, f'HTTP {code}')
                return
            time.sleep(3)
        self.step(f'{phase}: probe {spec.get("path", "/")}', False, last)

    def scan_logs(self, phase, since):
        result = self.compose('logs', '--no-color', '--timestamps', *(['--since', since] if since else []), check=False)
        text = result.stdout + result.stderr
        self.save(f'{phase}-logs.txt', text)
        allow = [a['text'] if isinstance(a, dict) else str(a) for a in self.spec.get('allow') or []]
        hits = [line for line in text.splitlines()
                if LOG_ERROR.search(line) and not any(a in line for a in allow)]
        detail = '\n'.join(hits[:40])
        if len(hits) > 40:
            detail += f'\n... {len(hits) - 40} more'
        self.step(f'{phase}: logs free of errors', not hits, detail)

    def functional(self, phase):
        hook = self.spec.get('functional')
        if not hook:
            return
        env = {**os.environ, **self.env, 'PHASE': phase, 'COMPOSE_PROJECT_NAME': self.project}
        result = sh(['bash', str(ROOT / 'verification' / hook)], cwd=self.workdir, env=env, timeout=600)
        self.save(f'{phase}-functional.txt', result.stdout + result.stderr)
        self.step(f'{phase}: functional {Path(hook).name}', result.returncode == 0,
                  (result.stdout + result.stderr)[-2000:])

    def up(self, phase):
        result = self.compose('up', '-d', '--wait', '--wait-timeout', str(self.timeout),
                              timeout=self.timeout + 120, check=False)
        self.save(f'{phase}-up.txt', result.stdout + result.stderr)
        self.step(f'{phase}: up --wait', result.returncode == 0, result.stderr)

    def cleanup(self, quiet=False):
        if self.workdir.exists():
            sh(['docker', 'compose', '-p', self.project, 'down', '-v', '--remove-orphans', '-t', '30'],
               cwd=self.workdir, timeout=300)
            image = getattr(self, 'prepare_image', None) or 'busybox:1.37.0-musl'
            # Rootless Docker maps container owners to subordinate ids, so delete through a container.
            sh(['docker', 'run', '--rm', '--user', '0', '-v', f'{self.workdir}:/w', '--entrypoint', 'sh', image,
                '-c', 'rm -rf /w/* /w/.[!.]*'], timeout=120)
            shutil.rmtree(self.workdir, ignore_errors=True)
        if not quiet and self.workdir.exists():
            print(f'[{self.name}] warning: {self.workdir} could not be removed', file=sys.stderr)

    def execute(self):
        self.started = time.time()
        self.results.mkdir(parents=True, exist_ok=True)
        status = 'failed'
        try:
            try:
                self.prepare_workdir()
                self.step('environment generated', True)
            except Exception as exc:
                self.step('environment generated', False, str(exc))
            if 'prepare' in self.services:
                result = self.compose('run', '--rm', 'prepare', timeout=600, check=False)
                self.save('prepare.txt', result.stdout + result.stderr)
                self.step('prepare exit 0', result.returncode == 0, result.stderr)
            self.up('initial')
            self.check_state('initial')
            self.probe('initial')
            self.scan_logs('initial', None)
            self.functional('initial')
            restart_at = dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
            result = self.compose('stop', '-t', '60', timeout=300, check=False)
            self.step('stop', result.returncode == 0, result.stderr)
            self.up('restart')
            self.check_state('restart')
            self.probe('restart')
            self.scan_logs('restart', restart_at)
            self.functional('restart')
            status = 'passed'
        except StepFailed:
            pass
        except Exception as exc:
            self.steps.append({'step': 'runner', 'ok': False, 'detail': repr(exc)})
            print(f'[{self.name}] FAIL runner: {exc!r}', flush=True)
        finally:
            if status == 'passed' or not self.args.keep:
                try:
                    self.cleanup()
                except Exception as exc:
                    print(f'[{self.name}] cleanup failed: {exc!r}', file=sys.stderr)
            else:
                print(f'[{self.name}] kept {self.workdir}', flush=True)
        summary = {'app': self.app, 'flavor': self.flavor, 'status': status,
                   'seconds': round(time.time() - self.started), 'steps': self.steps}
        self.save('result.json', json.dumps(summary, indent=2))
        return summary


class StepFailed(Exception):
    pass


def run(args):
    runs = [Run(app, flavor, args) for app, flavor in matrix(args)]
    if not runs:
        print('Nothing selected.')
        return 0
    results_root = Path(args.results).expanduser()
    results_root.mkdir(parents=True, exist_ok=True)
    print(f'Running {len(runs)} recipes with {args.jobs} parallel job(s); results in {results_root}')
    summaries = schedule(runs, args)
    summaries.sort(key=lambda s: (s['app'], s['flavor']))
    write_summary(results_root, summaries)
    failed = [s for s in summaries if s['status'] != 'passed']
    print()
    print(f"{len(summaries) - len(failed)} passed, {len(failed)} failed. Summary: {results_root / 'summary.md'}")
    return 1 if failed else 0


def memory_need(run):
    try:
        config = compose_config(run.source, run.source / '.env.example')
    except RuntimeError:
        return 0
    return sum(int(s.get('mem_limit') or 0) for s in config['services'].values()) // (1024 * 1024)


def schedule(runs, args):
    """Start runs in parallel while their summed container memory limits fit the budget."""
    total_mb = os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES') // (1024 * 1024)
    budget = args.memory or int(total_mb * 0.75)
    needs = {r.name: memory_need(r) for r in runs}
    pending = sorted(runs, key=lambda r: -needs[r.name])
    running = {}
    summaries = []
    lock = threading.Lock()
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        while pending or running:
            with lock:
                used = sum(needs[r.name] for r in running.values())
            started = False
            for r in list(pending):
                if len(running) >= args.jobs:
                    break
                if running and used + needs[r.name] > budget:
                    continue
                pending.remove(r)
                running[pool.submit(r.execute)] = r
                used += needs[r.name]
                started = True
            if not running:
                continue
            done, _ = concurrent.futures.wait(running, timeout=None if started or not pending else 5,
                                              return_when=concurrent.futures.FIRST_COMPLETED)
            for fut in done:
                summaries.append(fut.result())
                del running[fut]
    return summaries


def write_summary(root, summaries):
    (root / 'summary.json').write_text(json.dumps(summaries, indent=2))
    lines = ['# Verification run', '', f'Recorded {dt.datetime.now(dt.timezone.utc):%Y-%m-%d %H:%M} UTC.', '',
             '| Application | Flavour | Result | Seconds | Failed step |', '| --- | --- | --- | --- | --- |']
    for s in summaries:
        failed = next((st for st in s['steps'] if not st['ok']), None)
        detail = f"{failed['step']}: {failed['detail'].splitlines()[0][:100]}" if failed and failed['detail'] \
            else (failed['step'] if failed else '')
        lines.append(f"| {s['app']} | {s['flavor']} | {s['status']} | {s['seconds']} | {detail} |")
    (root / 'summary.md').write_text('\n'.join(lines) + '\n')


def list_matrix(args):
    for app, flavor in matrix(args):
        print(f'{flavor}/{app}')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    for name, func in (('static', static), ('run', run), ('list', list_matrix)):
        p = sub.add_parser(name)
        p.set_defaults(func=func)
        p.add_argument('--app', action='append', help='application folder name; repeatable')
        p.add_argument('--flavor', action='append', choices=FLAVORS)
        p.add_argument('--changed', metavar='REF', help='only applications whose files differ from REF')
        if name == 'run':
            p.add_argument('--jobs', type=int, default=1, help='recipes to run in parallel')
            p.add_argument('--memory', type=int, metavar='MB',
                           help='summed container memory limits allowed at once; default 75%% of RAM')
            p.add_argument('--workdir', default='~/.cache/docker-recipes-verify/work')
            p.add_argument('--results', default='~/.cache/docker-recipes-verify/results')
            p.add_argument('--keep', action='store_true', help='keep failed deployments for inspection')
    args = parser.parse_args()
    sys.exit(args.func(args))


if __name__ == '__main__':
    main()
