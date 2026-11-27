## repro.nim — the codetracer-visual-replay revision this library's
## downstream lane tests against.
##
## This is a project of its own, nested in codetracer-image-diff, with its own
## `repro.lock`. It pins exactly one repository, `codetracer-visual-replay`,
## and nothing is built from it. The library's own `repro.nim` (at the
## repository root) names what the library is BUILT from; visual-replay is its
## consumer, not one of those. Here it is a test pin, refreshed by hand.
##
## Consumer: `.github/workflows/downstream.yml`. Its `resolve` job reads the
## `codetracer-visual-replay` revision from `ci/downstream/repro.lock` (or takes
## a 40-hex `visual_replay_revision` from a manual dispatch), and its
## `visual-replay` job clones visual-replay at that commit beside this checkout
## and runs visual-replay's image-diff consumers against THIS revision of the
## library. Every other sibling that run needs comes from visual-replay's own
## pins at that commit. A branch tip is never used.
## `tests/test_downstream_lane.sh` holds the lock and the workflow to that.
##
## codetracer, the other consumer, is pinned in `ci/downstream/codetracer.pin`
## instead; that file says why.
##
## To move the pin: check codetracer-visual-replay out beside this repository
## at the new revision (a PUBLISHED commit: CI clones it), run
## `repro lock refresh .` in this directory, and commit the lock. The revision
## must carry visual-replay's `scripts/image-diff-consumers.sh`; the workflow
## refuses one that does not, and `tests/test_downstream_lane.sh` fails on one
## when the visual-replay checkout beside this one has the pinned commit.
import repro_project_dsl

package codetracer_image_diff_downstream:
  defaultToolProvisioning "path"
  uses:
    "codetracer-visual-replay"
  build:
    # Nothing is built here: visual-replay is consumed as source by the
    # downstream lane. A package with no `build:` block is not solved, so the
    # lock would record nothing.
    discard
