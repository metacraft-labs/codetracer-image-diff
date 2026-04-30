## Internal Nim binding to the FLIP C-ABI shim.
##
## Compiles `src/flip_wrapper.cpp` (which `#include`s
## `vendor/flip/FLIP.h`) and exposes `ct_flip_compute` to Nim. Used by
## the public API in `src/image_diff.nim` — application code should
## not import this module directly.

{.push raises: [].}

import std/os

const
  thisDir = currentSourcePath().parentDir().parentDir()
  vendorFlipDir = thisDir.parentDir() / "vendor" / "flip"
  wrapperCpp = thisDir / "flip_wrapper.cpp"

{.compile: wrapperCpp.}

# Add the FLIP single-header location and our wrapper header to the
# include path. FLIP.h itself is C++17-clean; we pin the standard
# explicitly so we don't depend on the toolchain default (which can be
# C++14 on some older nixpkgs revisions).
{.passC: "-I" & vendorFlipDir.}
{.passC: "-I" & thisDir.}
{.passC: "-std=c++17".}
{.passC: "-O2".}

# Link the C++ runtime. FLIP uses std::vector, std::string,
# std::pow / std::memcpy, etc.
{.passL: "-lstdc++".}

proc ct_flip_compute*(reference, candidate: ptr UncheckedArray[byte];
                      width, height, channels: cint;
                      outErrorMap: ptr ptr cfloat): cint
  {.importc, cdecl.}

proc ct_free*(p: pointer) {.importc: "free", header: "<stdlib.h>".}

{.pop.}
