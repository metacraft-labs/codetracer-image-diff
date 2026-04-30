# Patches applied to vendored FLIP source

**None.** The vendored `FLIP.h` (commit `b475eb4`, FLIP v1.7) is used
as-is. The single-header file compiles cleanly under

    g++ -std=c++17 -O2 -DNDEBUG src/flip_wrapper.cpp

when `FLIP_ENABLE_CUDA` is left undefined, which is our default. The
CUDA-only code paths inside `FLIP.h` are guarded by
`#ifdef FLIP_ENABLE_CUDA` and are not compiled.

If a future toolchain change requires modifications, document each
patch here as a *unified diff* with a one-paragraph rationale and an
explicit promise that no algorithmic logic was touched. The agreement
with upstream is: vendor verbatim where possible; build-glue patches
only.
