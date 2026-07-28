#!/usr/bin/env bash
# Sync the tech-watch workflow FROM the running n8n instance TO the repo.
# Run this after editing the workflow in the n8n UI, then review + commit.
set -euo pipefail
cd "$(dirname "$0")/.."

docker exec n8n-watch n8n export:workflow --id TechWatchDummy01 --output=/tmp/export.json >/dev/null
docker cp n8n-watch:/tmp/export.json /tmp/n8n-export.json >/dev/null

python3 - <<'EOF'
import json
ws = json.load(open('/tmp/n8n-export.json'))
w = ws[0] if isinstance(ws, list) else ws
keep = {k: w[k] for k in ('id', 'name', 'nodes', 'connections', 'settings') if k in w}
json.dump(keep, open('workflow/tech-watch.json', 'w'), indent=2, ensure_ascii=False)
print(f"workflow/tech-watch.json updated ({len(keep['nodes'])} nodes) — review with: git diff workflow/")
EOF
