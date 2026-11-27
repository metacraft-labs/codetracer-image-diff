default:
    @just --list

# This is a pure library — there's nothing to "build" as a binary. `repro
# build` materialises the build graph of `repro.nim`: every test binary is
# compiled (the `test-builds` collection), which compiles the library and
# catches type errors and missing imports. CI runs the same command.
build:
    repro build

# Direct compiler check of the library alone. We use `nim cpp` because the
# FLIP wrapper pulls in C++ via {.compile.}. It is the owning lint, not a
# build or test entry point; it creates no shipping binary.
check:
    nim cpp --noLinking -p:src src/image_diff.nim

# Owning lint is the real library compiler check. Formatting is checked by
# the complete portable hook set.
lint: check

# Run all five test files through `repro test` (the `test` collection of
# `repro.nim`: original four release profiles and locality debug).
test:
    repro test

# The downstream lane's wiring: .github/workflows/downstream.yml runs on push
# and pull_request to the mainline, calls codetracer's reusable
# image-diff-downstream.yml, runs codetracer-visual-replay's image-diff
# consumers on a GPU runner, and takes each consumer only from ci/downstream
# (repro.lock, codetracer.pin) or a 40-hex dispatch input, never a branch.
# Static (bash, grep, sed, awk, git); the lane's resolve job runs it first.
# Where a consumer is checked out beside this repository, it also checks that
# the pinned commit carries the consumer's driver.
test-downstream-lane:
    bash tests/test_downstream_lane.sh

clean:
    rm -rf nimcache
    rm -f tests/test_flip_identical tests/test_flip_different tests/test_flip_subpixel tests/test_flip_png
    rm -f tests/output/*.png
