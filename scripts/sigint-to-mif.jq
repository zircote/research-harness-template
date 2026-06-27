# sigint-to-mif.jq — convert a sigint findings_<dim>.json wrapper into a stream
# of MIF-backed finding units (one per .findings[] element), as NDJSON objects
# { "out": "<filename>.json", "doc": <mif-unit> } for the driver to write.
#
# Faithful, lossless-as-possible mapping (SPEC §8a/§8b, §10 import):
#   - real http(s) citations where the source carried a URL (incl. bare-domain
#     and embedded-URL recovery); an honest non-web `urn:corpus:` citation
#     carrying the original quote otherwise — never a fabricated web URL.
#   - W3C-PROV provenance preserved as sourceType=external_import.
#   - the prior adversarial verdict carried into extensions.harness.verification.
#
# Args: --arg topic <topic-id>

def slug: ascii_downcase | gsub("[^a-z0-9]+"; "-") | gsub("^-+|-+$"; "");
def norm_dim: ascii_downcase | gsub("[^a-z0-9_-]+"; "-") | gsub("^-+|-+$"; "");

def to_dt:
  if . == null or . == "" then "2026-01-01T00:00:00Z"
  elif (type == "string" and test("T")) then .
  elif (type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}")) then (.[0:10] + "T00:00:00Z")
  else "2026-01-01T00:00:00Z" end;

def to_date:
  if . == null or . == "" then null
  elif (type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}")) then .[0:10]
  else null end;

def conf:
  if type == "number" then (if . > 1 then (. / 100) else . end)
  elif . == "high" then 0.9
  elif (. == "medium" or . == "med") then 0.6
  elif . == "low" then 0.3
  else 0.6 end;

def trust:
  if . >= 0.85 then "high_confidence"
  elif . >= 0.6 then "moderate_confidence"
  elif . >= 0.4 then "low_confidence"
  else "uncertain" end;

def verdict_norm:
  if . == "survived" or . == "weakened" or . == "falsified" or . == "inconclusive" then .
  else "inconclusive" end;

# Drop null/absent optional keys (Citation/EntityReference are additionalProperties:false).
def compact: with_entries(select(.value != null));

# Accept both shapes: a {dimension, findings:[…]} wrapper, or a bare findings array.
(if type == "array" then { findings: . } else . end) as $root
| ($topic) as $topic
| ($srcfile | slug) as $sf
| (($root.dimension // ($srcfile | sub("^findings_"; "")) // "imported") | norm_dim) as $dim
| ($root.generated // null) as $gen
| ($root.findings // [])
| to_entries[]
| .key as $i
| .value as $f
| ((($f.id // ("f-" + (($f.title // "x")[0:24]))) | slug)) as $idslug
| ($sf + "-" + $idslug + "-" + ($i | tostring)) as $uid
| (($f.provenance.sources // []) | map(.url // empty | select(. != null and . != ""))) as $srcurls
| (($f.evidence // []) | map(select(type == "string"))) as $evid
| (($srcurls + $evid)
    | map(
        if test("https?://") then (capture("(?<u>https?://[^ \"<>]+)").u)
        elif test("^[a-z0-9][a-z0-9-]*\\.(com|org|net|io|dev|gov|edu|ai|co|us)([/ ]|$)")
          then ("https://" + (capture("(?<u>^[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}(/[^ \"<>]*)?)").u))
        else empty end)
    | map(select(. != null) | gsub("[.,;:)\\]]+$"; ""))
    | map(select(test("^https?://[^ \"<>]+$")))
    | unique) as $urls
| (($f.provenance.confidence // $f.confidence) | conf) as $confnum
| ((($f.provenance.sources // [])[0].fetched_at) // $gen) as $rawaccessed
| ($rawaccessed | to_date) as $accessed
| {
    out: ($uid + ".json"),
    doc: ({
      "@context": "https://mif-spec.dev/schema/context.jsonld",
      "@type": "Concept",
      "@id": ("urn:mif:concept:" + $topic + ":" + $uid),
      "conceptType": "semantic",
      "namespace": ("harness/" + $topic),
      "title": ($f.title // $f.claim // (($f.summary // "Untitled finding")[0:120])),
      "content": (($f.summary // $f.content // $f.title // $f.claim // "Imported finding (no content in source).") | if (. == "" or . == null) then "Imported finding (no content in source)." else . end),
      "summary": (($f.summary // $f.content // $f.title // "Imported finding.")[0:280]),
      "created": ($rawaccessed | to_dt),
      "relationships": (
        [ ($f.updates_finding // empty)
          | select(type == "string" and . != "")
          | { "type": "updates", "target": ("urn:mif:concept:" + $topic + ":" + (. | slug)), "strength": 0.9 } ]
        + [ ($f.updates_finding_id // empty)
          | select(type == "string" and . != "")
          | { "type": "updates", "target": ("urn:mif:concept:" + $topic + ":" + (. | slug)), "strength": 0.9 } ]
      ),
      "tags": (($f.tags // []) | map(slug) | map(select(length > 0)) | unique),
      "entities": (($f.entities // [])
        | map(select(type == "string"))
        | map({
            "@type": "EntityReference",
            "entity": { "@id": ("urn:mif:entity:concept:" + (. | slug)) },
            "entityType": "Concept",
            "name": .
          })),
      "provenance": {
        "@type": "Provenance",
        "sourceType": "external_import",
        "confidence": $confnum,
        "trustLevel": ($confnum | trust),
        "importedFrom": "sigint-corpus"
      },
      "citations": (
        if ($urls | length) > 0
        then ($urls[0:8] | map({
               "@type": "Citation",
               "citationType": "website",
               "citationRole": "supports",
               "title": (($f.title // "Source")[0:200]),
               "url": .,
               "accessed": $accessed
             } | compact))
        else [({
               "@type": "Citation",
               "citationType": "internal:document",
               "citationRole": "source",
               "title": (($evid[0] // $f.title // "Internal or quoted source carried from prior corpus")[0:200]),
               "url": ("urn:corpus:" + $topic + ":" + $uid),
               "note": (($evid[0] // $f.summary // $f.title // "Internal source; no web URL in prior corpus.")[0:1000])
             } | compact)]
        end),
      "extensions": {
        "harness": {
          "dimension": $dim,
          "sourceId": ($f.id // $idslug),
          "verification": {
            "verdict": (($f.verdict // $f.provenance.falsification_attempts[-1].verdict) | verdict_norm),
            "verdict_basis": (($f.verdict_basis // $f.provenance.falsification_attempts[-1].reason // "Imported from prior corpus; not re-verified in this harness.")[0:500])
          }
        }
      }
    } | compact)
  }
