#!/usr/bin/env bash
# downstream-revision.sh -- the consumer commit the downstream lane
# (.github/workflows/downstream.yml) tests this library against.
#
# Usage: scripts/downstream-revision.sh CONSUMER [DISPATCH_REVISION]
#   CONSUMER  codetracer-visual-replay | codetracer
#
# Prints `rev=<40-hex>` (a GITHUB_OUTPUT line) and exits 0, taking:
#   1. DISPATCH_REVISION, when it is non-empty -- the workflow_dispatch input
#      for that consumer. It must be exactly 40 lowercase hex digits: a
#      branch, a tag or a short sha is refused, not resolved;
#   2. otherwise the committed pin:
#        codetracer-visual-replay  the `deps` entry of ci/downstream/repro.lock
#        codetracer                the `codetracer=` line of
#                                  ci/downstream/codetracer.pin (that file says
#                                  why it is not in the lock)
# Anything else -- no pin file, no entry, a revision that is not 40-hex, an
# unknown consumer -- is an error (exit 1). A branch tip is never a fallback.
#
# REPRO_DOWNSTREAM_LOCK and CODETRACER_DOWNSTREAM_PIN name other pin files
# (the wiring test uses them).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock="${REPRO_DOWNSTREAM_LOCK:-$root/ci/downstream/repro.lock}"
pin="${CODETRACER_DOWNSTREAM_PIN:-$root/ci/downstream/codetracer.pin}"
consumer="${1:-}"
input="${2:-}"

err() {
  echo "::error::$*" >&2
  exit 1
}

case "$consumer" in
codetracer-visual-replay) source_file="$lock" ;;
codetracer) source_file="$pin" ;;
*) err "unknown consumer '$consumer' (expected codetracer-visual-replay or codetracer)" ;;
esac

if [ -n "$input" ]; then
  [[ "$input" =~ ^[0-9a-f]{40}$ ]] ||
    err "the dispatch revision for $consumer must be a 40-hex commit (got '$input'); the downstream lane never tests a branch or a tag"
  echo "$consumer revision: $input (from the workflow_dispatch input)" >&2
  echo "rev=$input"
  exit 0
fi

[ -f "$source_file" ] || err "$source_file does not exist; it is what pins the $consumer revision this lane tests against"
rev=""
if [ "$consumer" = codetracer-visual-replay ]; then
  # One `deps` entry per `{ ... }`; take the one named exactly
  # "codetracer-visual-replay".
  while IFS= read -r entry; do
    if [[ "$entry" =~ name\ =\ \"codetracer-visual-replay\" ]]; then
      [[ "$entry" =~ revision\ =\ \"([^\"]*)\" ]] && rev="${BASH_REMATCH[1]}"
    fi
  done < <(grep '^deps' "$source_file" | tr '{' '\n')
  [ -n "$rev" ] || err "$source_file pins no codetracer-visual-replay revision; refresh it with 'repro lock refresh .' in ci/downstream"
else
  # Exactly one non-comment line, `codetracer=<rev>`.
  lines="$(grep -vE '^[[:space:]]*(#.*)?$' "$source_file" || true)"
  [ "$(grep -c . <<<"$lines")" -eq 1 ] && [[ "$lines" == codetracer=* ]] ||
    err "$source_file must hold exactly one 'codetracer=<40-hex sha>' line besides comments (got: $(tr '\n' ' ' <<<"$lines"))"
  rev="${lines#codetracer=}"
fi
[[ "$rev" =~ ^[0-9a-f]{40}$ ]] || err "$source_file pins $consumer at '$rev', which is not a 40-hex revision"
echo "$consumer revision: $rev (from $source_file)" >&2
echo "rev=$rev"
