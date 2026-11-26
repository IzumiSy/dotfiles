#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

# Credentials must stay runtime-only and scoped to the intended destinations.
python3 - "$root/sbx/spec.yaml" <<'PY'
import pathlib
import sys

spec = pathlib.Path(sys.argv[1]).read_text()
assert "args:\n  copilot_host:\n    required: true\n    pattern: '^api\\.([a-z0-9-]+\\.)?githubcopilot\\.com$'" in spec
network = spec.split('\n  - type: com.docker.sandbox/network-policy@1\n')[1]
credentials = spec.split('\n  - type: com.docker.sandbox/credential@1\n')[1:]
assert len(credentials) == 2
for block, service, variable, domains in zip(credentials, ('github', 'pi-copilot'),
        ('GH_TOKEN', 'COPILOT_GITHUB_TOKEN'),
        (('api.github.com', 'github.com'), ("'${{ kit.args.copilot_host }}'",))):
    block = block.split('\n  - type:', 1)[0]
    assert f'      service: {service}\n' in block
    assert '      phase: runtime\n' in block
    assert f'        name: {variable}\n' in block
    assert '        proxyManaged: true\n' in block
    assert block.count('          - domain: ') == len(domains)
    assert block.count('            header: Authorization\n') == len(domains)
    assert block.count('            format: "Bearer %s"\n') == len(domains)
    for domain in domains:
        assert f'          - domain: {domain}\n' in block
        assert f'          - {domain}\n' in network, f'inject domain {domain} needs an explicit allow entry'
for domain in ('github.com', "'**.github.com'", "'**.githubcopilot.com'",
        "'**.tailor.tech'", "'**.google.com'", "'**.googleapis.com'", "'**.erp.dev'",
        'pi.dev'):
    assert f'          - {domain}\n' in network
PY

printf 'sbx credential scope checks passed\n'
