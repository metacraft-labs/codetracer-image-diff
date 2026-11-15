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

clean:
    rm -rf nimcache
    rm -f tests/test_flip_identical tests/test_flip_different tests/test_flip_subpixel tests/test_flip_png
    rm -f tests/output/*.png
