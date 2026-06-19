#!/usr/bin/env bash
# build-graph-viz.sh — render the MIF-native knowledge graph as a standalone
# HTML visualization (SPEC §4a: "keep the HTML graph visualization as an
# output"). Self-contained: it embeds the graph JSON and a tiny force-free
# adjacency rendering with no external network dependency.
#
# Usage: build-graph-viz.sh <knowledge-graph.json> [<out.html>]

set -uo pipefail
G="${1:?usage: build-graph-viz.sh <knowledge-graph.json> [out.html]}"
OUT="${2:-${G%.json}.html}"
[ -f "$G" ] || { echo "build-graph-viz: not found: $G" >&2; exit 2; }

DATA=$(cat "$G")
NODES=$(jq '.nodes|length' "$G")
EDGES=$(jq '.edges|length' "$G")

cat > "$OUT" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Knowledge graph (MIF-native)</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 2rem; color: #1a1a1a; }
  h1 { font-size: 1.2rem; }
  .concept { color: #0b5; } .entity { color: #06c; }
  li { margin: .2rem 0; } code { background: #f4f4f4; padding: 0 .2rem; }
</style>
</head>
<body>
<h1>Knowledge graph — $NODES nodes, $EDGES edges (built from MIF entities and relations)</h1>
<h2>Nodes</h2>
<ul id="nodes"></ul>
<h2>Edges (typed MIF relationships and entity mentions)</h2>
<ul id="edges"></ul>
<script id="graph" type="application/json">$DATA</script>
<script>
  const g = JSON.parse(document.getElementById('graph').textContent);
  const nl = document.getElementById('nodes');
  for (const n of g.nodes) {
    const li = document.createElement('li');
    li.innerHTML = '<span class="' + n.kind + '">' + n.kind + '</span> — <strong>' +
      n.label + '</strong> <code>' + n.id + '</code>';
    nl.appendChild(li);
  }
  const el = document.getElementById('edges');
  for (const e of g.edges) {
    const li = document.createElement('li');
    li.innerHTML = '<code>' + e.source + '</code> —<strong>' + e.type +
      '</strong>&rarr; <code>' + e.target + '</code>';
    el.appendChild(li);
  }
</script>
</body>
</html>
HTML

echo "build-graph-viz: wrote $OUT"
