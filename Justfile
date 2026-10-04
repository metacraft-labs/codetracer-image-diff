default:
    @just --list

# This is a pure library — there's nothing to "build" as a binary.
# `just build` runs a compile-check that catches type errors and
# missing imports without producing an executable. We use `nim cpp`
# because the FLIP wrapper pulls in C++ via {.compile.}.
build:
    nim cpp --noLinking -p:src src/image_diff.nim

# Owning lint is the existing real library compiler check; it creates no
# shipping binary. Formatting is checked by the complete portable hook set.
lint: build

# Run all five test files: original four release profiles and locality debug.
test:
    nimble test

clean:
    rm -rf nimcache
    rm -f tests/test_flip_identical tests/test_flip_different tests/test_flip_subpixel tests/test_flip_png
    rm -f tests/output/*.png
