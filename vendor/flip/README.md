# vendor/flip

Subset of NVIDIA's [FLIP reference implementation](https://github.com/NVlabs/flip),
vendored at upstream commit
[`b475eb4`](https://github.com/NVlabs/flip/commit/b475eb4bf394ab877c42166c9eb0a84a02cc5b14)
(release tag v1.7).

## What we vendor

Only `FLIP.h` and the upstream `LICENSE`. FLIP's C++ implementation is
delivered as a single header — the entire CPU evaluator (image class,
contrast-sensitivity / feature-detection passes, LDR + HDR pipelines,
magma colour map, sRGB↔linear-RGB↔YCxCz conversions, pooling helpers)
lives in this one file, ~2.5K LoC. CUDA paths are guarded by
`#ifdef FLIP_ENABLE_CUDA`, which the build never defines.

## What we do *not* vendor

| Upstream path                            | Why omitted                                     |
| ---------------------------------------- | ----------------------------------------------- |
| `src/cpp/tool/`                          | Standalone CLI binary, CLI parsing, EXR/HDR I/O |
| `src/cpp/tool/stb_image*.h, tinyexr.h`   | Image I/O for the CLI; we use stb separately    |
| `src/cpp/FLIP-tool.cu`, `src/cuda/`      | CUDA acceleration                               |
| `src/python/`, `src/pytorch/`, etc.      | Other-language bindings                         |
| `src/tests/`, `src/flip_evaluator/`      | Upstream's own test data and Python pkg         |
| Top-level `CMakeLists.txt`, Bazel, etc.  | Build glue irrelevant for `{.compile.}` use     |

## How we build it

We do *not* use upstream's CMake. Instead, `src/flip_wrapper.cpp`
includes `FLIP.h` (C++) and exposes a C-ABI shim
(`ct_flip_compute(...)`) that Nim's `importc` can bind.
`src/image_diff/flip_backend.nim` registers the wrapper TU via
`{.compile.}` and arranges `-lstdc++` for the C++ runtime.

## Patches applied

None. The single-header builds cleanly under `g++ -std=c++17` once
`FLIP_ENABLE_CUDA` is left undefined. See `PATCHES.md`.
