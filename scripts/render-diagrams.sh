#!/usr/bin/env bash
# Renders every Mermaid source in assets/diagrams/*.mmd to an SVG file next to it.
# Pages embed the SVG files, so readers need no Mermaid library at runtime.
# Needs the Mermaid CLI: npm install -g @mermaid-js/mermaid-cli
set -euo pipefail

DIAGRAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../assets/diagrams" && pwd)"
CONFIG="$(mktemp)"
trap 'rm -f "$CONFIG"' EXIT
# Plain SVG text instead of HTML labels, so the files render inside <img> everywhere.
printf '%s\n' '{"theme": "neutral", "htmlLabels": false, "flowchart": {"htmlLabels": false, "wrappingWidth": 300}}' >"$CONFIG"

for source in "$DIAGRAM_DIR"/*.mmd; do
  target="${source%.mmd}.svg"
  mmdc --input "$source" --output "$target" --configFile "$CONFIG" --backgroundColor white --quiet
  echo "Rendered $(basename "$target")"
done
