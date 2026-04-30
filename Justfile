default:
    @just --list

# This is a pure library — there's nothing to "build" as a binary.
# `just build` runs a compile-check that catches type errors and
# missing imports without producing an executable. We use `nim cpp`
# because the FLIP wrapper pulls in C++ via {.compile.}.
build:
    nim cpp --noLinking -p:src src/image_diff.nim

# Run the full test suite (release-mode, all four test files).
test:
    nimble test

clean:
    rm -rf nimcache
    rm -f tests/test_flip_identical tests/test_flip_different tests/test_flip_subpixel tests/test_flip_png
    rm -f tests/output/*.png
