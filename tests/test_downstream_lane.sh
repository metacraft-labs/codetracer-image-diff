#!/usr/bin/env bash
# The workflow text this suite matches carries literal `${{ ... }}` and `${VAR}`
# expressions, which must NOT expand here.
# shellcheck disable=SC2016
# test_downstream_lane.sh -- this library has a downstream lane that checks a
# change against both of its consumers, codetracer-visual-replay and
# codetracer, and that lane pins both.
#
# Both consumers compile this library from source: visual-replay's
# software-vs-hardware replay tests compare frames with FLIP, and codetracer's
# PLAT-37 parity tooling compiles src/flip_wrapper.cpp while story_diff
# imports image_diff. So a change here must be run against them before it
# lands on the mainline. This test fails on a tree that has no such lane, and
# on a lane (.github/workflows/downstream.yml) that:
#   * does not run on push and pull_request to dev (the mainline), with the
#     branches ci-reprobuild.yml uses, or cannot be dispatched with a 40-hex
#     revision of each consumer;
#   * takes a consumer from anywhere but ci/downstream (repro.lock for
#     visual-replay, codetracer.pin for codetracer) or a 40-hex
#     workflow_dispatch input -- in particular from a branch tip;
#   * does not call codetracer's reusable image-diff-downstream.yml with the
#     resolved revision and the inherited secrets;
#   * in its visual-replay job: validates the revision after cloning anything,
#     interpolates a `${{ }}` expression into a script body, checks out
#     anything but `github.sha` as the library, misses a script it runs in its
#     "predates this lane" refusal (whose script is EXTRACTED AND RUN here
#     against fixture checkouts), takes its siblings from anywhere but
#     visual-replay's own resolver, runs the driver without
#     `--expect-image-diff-rev` set to the checked-out commit, or runs on a
#     runner without a GPU;
#   * pins a consumer at a non-40-hex revision, or -- when that consumer's
#     checkout beside this one has the pinned commit -- at a commit that does
#     not carry the consumer's driver.
# Mutations of a copy of the workflow, each of which must be rejected, keep
# the checks themselves honest, with a positive control on the unmutated copy.
#
# The revision resolver (scripts/downstream-revision.sh) is RUN, against the
# committed pins and against fixture pins written here. No mocks: the inputs
# are this repository's own files, temporary copies of them and throwaway git
# repositories made here.
#
# Run: bash tests/test_downstream_lane.sh   (stock bash, grep, sed, awk, git;
# no network). `just test-downstream-lane`; the lane's resolve job runs it.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF="$ROOT/.github/workflows/downstream.yml"
CI="$ROOT/.github/workflows/ci-reprobuild.yml"
NIM="$ROOT/ci/downstream/repro.nim"
RESOLVER="$ROOT/scripts/downstream-revision.sh"
REUSABLE="metacraft-labs/codetracer/.github/workflows/image-diff-downstream.yml@"
SHA=0123456789abcdef0123456789abcdef01234567

pass=0 failn=0
ok() {
  pass=$((pass + 1))
  echo "  ok   $1"
}
fail() {
  failn=$((failn + 1))
  echo "  FAIL $1"
  shift
  for l in "$@"; do echo "       $l"; done
}
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# The top-level `on:` block's `<event>:` section, as text.
on_event() { # $1 = event name, $2 = workflow file
  awk -v ev="$1" '
    /^on:/ { inon = 1; next }
    inon && /^[^ #]/ { inon = 0 }
    inon && $0 ~ "^  " ev ":" { inev = 1; next }
    inon && inev && /^  [^ ]/ { inev = 0 }
    inon && inev { print }' "$2"
}
# The `branches:` list of an `on:` event, one name per line.
event_branches() { on_event "$1" "$2" | sed -n 's/^ *branches: *\[\(.*\)\].*/\1/p' | tr ',' '\n' | tr -d ' '; }
# The text of one job (`  <name>:` up to the next job).
job_text() { # $1 = job id, $2 = workflow file
  awk -v j="$1" '
      /^jobs:/ { in_jobs = 1; next }
      in_jobs && $0 ~ "^  " j ":" { injob = 1; print; next }
      in_jobs && injob && /^  [A-Za-z0-9_-]+:/ { injob = 0 }
      injob { print }' "$2"
}
# step_script JOB NAME FILE -> that step's `run: |` body, dedented.
step_script() {
  job_text "$1" "$3" | awk -v want="      - name: $2" '
      $0 == want { in_step=1; next }
      in_step && /^      - name: / { in_step=0 }
      in_step && /^        run: \|[[:space:]]*$/ { in_run=1; next }
      in_run && /^          / { sub(/^          /, ""); print; next }
      in_run && /^[[:space:]]*$/ { print ""; next }
      in_run { in_run=0; in_step=0 }
    '
}

# run_plan FILE REVISION -> "<rc>" + the step's outputs
run_plan() {
  local ws="$tmp/runner/codetracer-image-diff/codetracer-image-diff" rc
  step_script visual-replay "Plan the workspace layout" "$1" >"$tmp/plan.sh"
  mkdir -p "$ws"
  : >"$tmp/out" && : >"$tmp/summary"
  (cd "$ws" && GITHUB_REPOSITORY="metacraft-labs/codetracer-image-diff" GITHUB_WORKSPACE="$ws" \
    GITHUB_OUTPUT="$tmp/out" GITHUB_STEP_SUMMARY="$tmp/summary" \
    VR_REV="$2" SELF_SHA="$SHA" bash "$tmp/plan.sh" >/dev/null 2>&1) && rc=0 || rc=$?
  echo "$rc"
  cat "$tmp/out"
}

# The repo-relative paths later steps of the visual-replay job run or read
# from the visual-replay checkout, and the ones the refusal step checks.
vr_paths_used() {
  job_text visual-replay "$1" | grep -oE '"\$\{VR_DIR\}/(scripts|tests)/[A-Za-z0-9_./-]+"' | sed 's/^"${VR_DIR}\///; s/"$//' | sort -u
  echo scripts/image-diff-consumers.sh
}
refusal_list() {
  step_script visual-replay "Refuse a visual-replay revision that predates this lane" "$1" |
    grep -oE '(scripts|tests)/[A-Za-z0-9_./-]+\.sh' | sort -u
}
# run_refusal FILE MISSING -> rc of the refusal step on a fixture checkout that
# lacks MISSING (a path, or `recipe` for the driver's just recipe).
run_refusal() {
  local vr="$tmp/refuse/codetracer-visual-replay" s
  rm -rf "$tmp/refuse"
  mkdir -p "$vr"
  git init -q "$vr"
  git -C "$vr" -c user.email=t@t -c user.name=t commit -q --allow-empty -m fixture
  for s in $(refusal_list "$1"); do
    mkdir -p "$vr/$(dirname "$s")"
    : >"$vr/$s"
  done
  printf 'test-image-diff-consumers *args:\n    bash scripts/image-diff-consumers.sh {{args}}\ninstall-native-replay-companion:\n    true\n' >"$vr/Justfile"
  case "$2" in
  "") ;;
  recipe) sed -i '/^test-image-diff-consumers/d' "$vr/Justfile" ;;
  *) rm -f "$vr/$2" ;;
  esac
  step_script visual-replay "Refuse a visual-replay revision that predates this lane" "$1" >"$tmp/refuse.sh"
  VR_DIR="$vr" bash "$tmp/refuse.sh" >"$tmp/refuse.out" 2>&1
}

# violations FILE -> one line per broken property of the workflow; empty = good.
violations() {
  local f="$1" r s ev plan_line first_clone
  [ -f "$f" ] || {
    echo "no workflow"
    return
  }
  for ev in push pull_request; do
    grep -qx dev <<<"$(event_branches "$ev" "$f")" || echo "on.$ev does not include dev"
    [ "$(event_branches "$ev" "$f" | sort | paste -sd, -)" = "$(event_branches "$ev" "$CI" | sort | paste -sd, -)" ] ||
      echo "on.$ev branches differ from ci-reprobuild.yml's"
  done
  for i in visual_replay_revision codetracer_revision; do
    grep -q "^      $i:" <<<"$(on_event workflow_dispatch "$f")" || echo "workflow_dispatch takes no $i input"
  done
  grep -qF "cancel-in-progress: \${{ github.event_name == 'pull_request' }}" "$f" ||
    echo "concurrency does not cancel superseded pull-request runs only"
  # The resolve job.
  r="$(job_text resolve "$f")"
  grep -qx '        run: bash tests/test_downstream_lane.sh' <<<"$r" || echo "the resolve job does not run tests/test_downstream_lane.sh"
  grep -qF 'run: bash scripts/downstream-revision.sh codetracer-visual-replay "${INPUT_REV}" >>"${GITHUB_OUTPUT}"' <<<"$r" &&
    grep -qF 'INPUT_REV: ${{ github.event.inputs.visual_replay_revision }}' <<<"$r" ||
    echo "the resolve job does not read the visual-replay revision through the resolver, fed only the dispatch input"
  grep -qF 'run: bash scripts/downstream-revision.sh codetracer "${INPUT_REV}" >>"${GITHUB_OUTPUT}"' <<<"$r" &&
    grep -qF 'INPUT_REV: ${{ github.event.inputs.codetracer_revision }}' <<<"$r" ||
    echo "the resolve job does not read the codetracer revision through the resolver, fed only the dispatch input"
  # The codetracer job: a thin caller.
  r="$(job_text codetracer "$f")"
  grep -qF "uses: $REUSABLE" <<<"$r" || echo "the codetracer job does not call $REUSABLE..."
  [ "$(sed -n 's/^ *codetracer-revision: *//p' <<<"$r")" = '${{ needs.resolve.outputs.codetracer-rev }}' ] ||
    echo "codetracer-revision is not exactly the resolve job's codetracer-rev"
  [ "$(grep -cE '^      [a-z0-9_-]+:' <<<"$(awk '/^    with:/ { w = 1; next } w && /^    [^ ]/ { w = 0 } w' <<<"$r")")" -eq 1 ] ||
    echo "the codetracer job passes more than its one input"
  grep -qE '^    secrets: *inherit *$' <<<"$r" || echo "the codetracer job does not inherit secrets"
  # The visual-replay job.
  r="$(job_text visual-replay "$f")"
  grep -qE '^    runs-on: \[self-hosted, gpu\]' <<<"$r" || echo "the visual-replay job does not run on [self-hosted, gpu]"
  grep -qE '^    timeout-minutes: [0-9]+' <<<"$r" || echo "the visual-replay job has no timeout-minutes"
  plan_line=$(grep -n 'name: Plan the workspace layout' <<<"$r" | head -1 | cut -d: -f1)
  first_clone=$(grep -nE 'fetch -q|uses: metacraft-labs/metacraft-github-actions/setup-dev-env' <<<"$r" | head -1 | cut -d: -f1)
  { [ -n "$plan_line" ] && [ -n "$first_clone" ] && [ "$plan_line" -lt "$first_clone" ]; } ||
    echo "the plan step does not come before every clone"
  grep -qF 'VR_REV: ${{ needs.resolve.outputs.visual-replay-rev }}' <<<"$r" || echo "the plan step does not take the resolve job's visual-replay-rev"
  s="$(run_plan "$f" "$SHA")"
  [ "$(head -1 <<<"$s")" = 0 ] && grep -qx "vr-rev=$SHA" <<<"$s" && grep -qE '^vr-dir=.*/codetracer-visual-replay$' <<<"$s" ||
    echo "the plan step does not accept a 40-hex revision and plan ../codetracer-visual-replay"
  for bad in dev agents "${SHA:0:12}" "${SHA^^}" "" "refs/heads/dev"; do
    [ "$(run_plan "$f" "$bad" | head -1)" = 0 ] && echo "the plan step accepts visual-replay revision '$bad'"
  done
  awk '
      match($0, /^ *run: *\|/) { body = 1; ind = RSTART + index(substr($0, RSTART), "r") - 1; next }
      body && /^ *$/ { next }
      body { match($0, /^ */); if (RLENGTH < ind) body = 0 }
      body && /\$\{\{/ { print NR ": " $0 }
    ' "$f" | grep -q . && echo "a script body interpolates a \${{ }} expression"
  [ "$(grep -c '          ref: ${{ github.sha }}' <<<"$r")" -eq 1 ] || echo "the library is not checked out at github.sha"
  grep -qF 'just test-image-diff-consumers --expect-image-diff-rev "${SELF_SHA}"' <<<"$r" &&
    [ "$(grep -c 'SELF_SHA: ${{ github.sha }}' <<<"$r")" -ge 2 ] ||
    echo "the driver does not run with --expect-image-diff-rev set to github.sha"
  grep -qF 'bash "${VR_DIR}/scripts/image-diff-downstream-siblings.sh"' <<<"$r" &&
    grep -qF '${{ steps.resolve.outputs.siblings }}' <<<"$r" ||
    echo "the siblings do not come from visual-replay's scripts/image-diff-downstream-siblings.sh"
  grep -qF 'run: bash "${VR_DIR}/tests/test_image_diff_downstream_lane.sh"' <<<"$r" ||
    echo "the visual-replay job does not run visual-replay's wiring test"
  if grep -nE '(^ *ref: *(main|dev|stable|agents)\b|refs/heads/|^\s+[A-Za-z0-9_.-]+=[0-9a-f]{40})' "$f" >/dev/null; then
    echo "the workflow names a branch or a revision of its own"
  fi
  # The refusal step covers what the job runs, and refuses a checkout that lacks any of it.
  while read -r s; do
    [ -n "$s" ] || continue
    grep -qxF "$s" <<<"$(refusal_list "$f")" || echo "the job uses $s but the refusal step does not check it"
  done < <(vr_paths_used "$f")
  for s in $(refusal_list "$f") recipe; do
    run_refusal "$f" "$s" && echo "the refusal step accepts a checkout without $s"
  done
  run_refusal "$f" "" || echo "the refusal step refuses a complete checkout: $(cat "$tmp/refuse.out")"
}

echo "== the downstream workflow exists"
if [ ! -f "$WF" ]; then
  fail "$WF exists" "this library has no workflow that runs its consumers against a change"
  echo
  echo "test_downstream_lane: $failn of $((pass + failn)) assertions FAILED"
  exit 1
fi
ok "$WF exists"

echo "== its triggers, its resolve job, its codetracer caller and its visual-replay job"
v="$(violations "$WF")"
if [ -z "$v" ]; then ok "every property holds"; else fail "the workflow" "${v//$'\n'/$'\n'       }"; fi
if [ "$(vr_paths_used "$WF" | grep -c .)" -ge 3 ] && [ "$(refusal_list "$WF" | grep -c .)" -ge 4 ]; then
  ok "anti-vacuity: the scanners find the visual-replay paths the job uses ($(vr_paths_used "$WF" | paste -sd' ' -))"
else
  fail "anti-vacuity: the scanners find the visual-replay paths the job uses"
fi

echo "== ci/downstream pins both consumers at 40-hex revisions"
if [ -f "$NIM" ] && grep -qE '^ *"codetracer-visual-replay"$' "$NIM"; then
  ok "ci/downstream/repro.nim uses \"codetracer-visual-replay\""
else
  fail "ci/downstream/repro.nim uses \"codetracer-visual-replay\""
fi
declare -A pinned=()
for c in codetracer-visual-replay codetracer; do
  if out="$(bash "$RESOLVER" "$c" "" 2>"$tmp/err")" && [[ "$out" =~ ^rev=[0-9a-f]{40}$ ]]; then
    pinned[$c]="${out#rev=}"
    ok "$c is pinned at a 40-hex revision (${out#rev=})"
  else
    fail "$c is pinned at a 40-hex revision" "$out" "$(cat "$tmp/err")"
  fi
done

echo "== each pin carries its consumer's driver (checked where the consumer is checked out)"
# The lane refuses a pin that predates the driver, but only on a runner; here
# it is caught before a push, wherever the consumer's checkout beside this one
# has the pinned commit.
for c in codetracer-visual-replay codetracer; do
  case "$c" in
  codetracer-visual-replay) files="scripts/image-diff-consumers.sh scripts/image-diff-downstream-siblings.sh tests/test_image_diff_downstream_lane.sh" ;;
  codetracer) files="ci/test/image-diff-consumers.sh .github/workflows/image-diff-downstream.yml" ;;
  esac
  dir="$ROOT/../$c" rev="${pinned[$c]:-}"
  if [ -z "$rev" ]; then
    continue
  elif ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    echo "  note $c is not checked out beside this repository; its pin $rev was not checked for the driver"
  elif ! git -C "$dir" cat-file -e "$rev^{commit}" 2>/dev/null; then
    echo "  note $dir does not have $rev (fetch it); the pin was not checked for the driver"
  else
    missing=""
    for p in $files; do git -C "$dir" cat-file -e "$rev:$p" 2>/dev/null || missing="$missing $p"; done
    if [ -z "$missing" ]; then
      ok "$c@$rev carries the lane's driver ($files)"
    else
      fail "$c@$rev carries the lane's driver" "missing:$missing" "move the pin (see ci/downstream/repro.nim or codetracer.pin) to a published commit that has them"
    fi
  fi
done

echo "== the resolver accepts only the pins or a 40-hex dispatch input"
for c in codetracer-visual-replay codetracer; do
  out="$(bash "$RESOLVER" "$c" "$SHA" 2>/dev/null)"
  if [ "$out" = "rev=$SHA" ]; then ok "$c: a 40-hex dispatch input wins over the pin"; else fail "$c: a 40-hex dispatch input wins" "$out"; fi
  for bad in dev main agents v1.0.0 0123456 "${SHA^^}" "$SHA "; do
    if bash "$RESOLVER" "$c" "$bad" >/dev/null 2>&1; then fail "$c: dispatch input '$bad' is refused"; else ok "$c: dispatch input '$bad' is refused"; fi
  done
done
if bash "$RESOLVER" codetracer-image-diff "" >/dev/null 2>&1 || bash "$RESOLVER" >/dev/null 2>&1; then
  fail "an unknown or missing consumer is refused"
else
  ok "an unknown or missing consumer is refused"
fi
entry() { printf '{ name = "%s", coord_kind = "vcs", url = "https://github.com/metacraft-labs/%s", revision = "%s", integrity = "", version = "", visibility = "public", participation = "", depends = "", tags = "" }' "$1" "$1" "$2"; }
mklock() { printf 'schema = "reprobuild.solved-graph-lock.v3"\n\n[lock]\ndeps = [%s]\n' "$1" >"$tmp/lock"; }
vr_fixture() { REPRO_DOWNSTREAM_LOCK="$tmp/lock" bash "$RESOLVER" codetracer-visual-replay "" 2>/dev/null; }
mklock "$(entry codetracer-image-diff "$SHA"), $(entry codetracer-visual-replay "$SHA")"
if [ "$(vr_fixture)" = "rev=$SHA" ]; then ok "POSITIVE CONTROL: a fixture lock pinning codetracer-visual-replay resolves"; else fail "a fixture lock pinning codetracer-visual-replay resolves"; fi
mklock "$(entry codetracer-visual-replay dev)"
if vr_fixture >/dev/null; then fail "a lock pinning codetracer-visual-replay at a branch is refused"; else ok "a lock pinning codetracer-visual-replay at a branch is refused"; fi
mklock "$(entry codetracer-visual-replay-fixtures "$SHA")"
if vr_fixture >/dev/null; then fail "a lock that pins no codetracer-visual-replay is refused (no branch fallback)"; else ok "a lock that pins no codetracer-visual-replay is refused (no branch fallback)"; fi
rm -f "$tmp/lock"
if vr_fixture >/dev/null; then fail "a missing lock is refused"; else ok "a missing lock is refused"; fi
ct_fixture() {
  printf '%s\n' "$@" >"$tmp/pin"
  CODETRACER_DOWNSTREAM_PIN="$tmp/pin" bash "$RESOLVER" codetracer "" 2>/dev/null
}
if [ "$(ct_fixture '# a comment' "codetracer=$SHA")" = "rev=$SHA" ]; then ok "POSITIVE CONTROL: a fixture codetracer.pin resolves"; else fail "a fixture codetracer.pin resolves"; fi
for bad in "codetracer=dev" "codetracer=${SHA:0:12}" "codetracer-image-diff=$SHA" "codetracer=$SHA|codetracer=$SHA" "# only a comment"; do
  IFS='|' read -r -a lines <<<"$bad"
  if ct_fixture "${lines[@]}" >/dev/null; then fail "codetracer.pin '$bad' is refused"; else ok "codetracer.pin '$bad' is refused"; fi
done
rm -f "$tmp/pin"
if CODETRACER_DOWNSTREAM_PIN="$tmp/pin" bash "$RESOLVER" codetracer "" >/dev/null 2>&1; then fail "a missing codetracer.pin is refused"; else ok "a missing codetracer.pin is refused"; fi

echo "== mutations of the workflow (each must be rejected)"
mutate() { # NAME SED-EXPR
  local m="$tmp/mut.yml"
  sed -E "$2" "$WF" >"$m"
  if cmp -s "$m" "$WF"; then
    fail "mutation '$1' changed nothing (the mutation is stale)"
    return
  fi
  if [ -n "$(violations "$m")" ]; then ok "rejected: $1"; else fail "NOT rejected: $1"; fi
}
mutate "the plan accepts a branch" 's/if ! \[\[ "\$\{VR_REV\}" =~ \^\[0-9a-f\]\{40\}\$ \]\]; then/if false; then/'
mutate "the plan interpolates the revision" 's/echo "visual-replay revision:       \$\{VR_REV\}"/echo "visual-replay revision: ${{ needs.resolve.outputs.visual-replay-rev }}"/'
mutate "the library is checked out at a branch" '0,/^          ref: \$\{\{ github.sha \}\}/s//          ref: dev/'
mutate "the refusal forgets the driver" 's|for script in scripts/image-diff-consumers.sh |for script in |'
mutate "the refusal forgets the wiring test" 's| tests/test_image_diff_downstream_lane.sh; do|; do|'
mutate "the refusal forgets the recipe" 's/for recipe in test-image-diff-consumers /for recipe in /'
mutate "the driver is not held to the checked-out commit" 's/ --expect-image-diff-rev "\$\{SELF_SHA\}"//'
mutate "the visual-replay job leaves the GPU runner" 's/^    runs-on: \[self-hosted, gpu\]/    runs-on: [self-hosted, linux, x64]/'
mutate "the codetracer job pins its own revision" 's/codetracer-revision: \$\{\{ needs.resolve.outputs.codetracer-rev \}\}/codetracer-revision: 40a82a1e35de22919358cb0292bd2162ae34d699/'
mutate "the codetracer job drops the inherited secrets" '/^    secrets: inherit$/d'
mutate "pull requests to dev stop triggering it" '0,/branches: \[main, dev, stable\]/!{0,/branches: \[main, dev, stable\]/s//branches: [main, stable]/}'
mutate "the resolve job skips this test" '/^        run: bash tests\/test_downstream_lane.sh$/d'
cp "$WF" "$tmp/control.yml"
if [ -z "$(violations "$tmp/control.yml")" ]; then ok "POSITIVE CONTROL: the unmutated copy passes"; else fail "POSITIVE CONTROL: the unmutated copy passes"; fi

echo
if [ "$failn" -eq 0 ]; then
  echo "test_downstream_lane: $pass assertions passed"
else
  echo "test_downstream_lane: $failn of $((pass + failn)) assertions FAILED"
  exit 1
fi
