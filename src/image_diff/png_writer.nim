## Minimal PNG writer for FLIP error maps.
##
## Wraps Sean Barrett's `stb_image_write` (vendored under
## `vendor/stb/stb_image_write.h`) — single-header, public domain. We
## instantiate the implementation in *exactly one* translation unit by
## emitting the include with `STB_IMAGE_WRITE_IMPLEMENTATION` defined.
##
## The visualization is a magma-style colour map: the float error in
## [0, 1] is mapped to a perceptually-uniform RGB ramp (black → purple
## → red → orange → yellow). This matches what FLIP's own tool produces
## for its `applyMagmaMapToOutput=true` mode, so a developer who has
## seen FLIP output before will recognize the colours.

{.push raises: [].}

import std/os

const
  stbDir = currentSourcePath().parentDir().parentDir().parentDir() /
           "vendor" / "stb"

{.passC: "-I" & stbDir.}

# Define the implementation in this translation unit only. We keep the
# stdio writers (we call `stbi_write_png` with a filename) but rely on
# the linker to drop the JPG/HDR/BMP/TGA writers we never reference.
{.emit: """
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"
""".}

proc stbi_write_png(filename: cstring; w, h, comp: cint;
                    data: pointer; strideInBytes: cint): cint
  {.importc, header: "stb_image_write.h".}

# ---------------------------------------------------------------------------
# Magma-style colour map.
# ---------------------------------------------------------------------------
#
# Compact 9-stop sample of matplotlib's `magma` palette (perceptually
# uniform, public domain). The full LUT is 256 entries; this 9-point
# piecewise-linear approximation is visually indistinguishable for our
# purposes (an error-map preview, not a publication-quality figure) and
# avoids vendoring another large data table.
const magmaStops: array[9, array[3, float32]] = [
  [0.0010f, 0.0004f, 0.0139f],   # near-black
  [0.0900f, 0.0454f, 0.2415f],   # deep purple
  [0.2541f, 0.0606f, 0.4260f],
  [0.4222f, 0.1187f, 0.4961f],
  [0.5805f, 0.1772f, 0.5046f],
  [0.7332f, 0.2350f, 0.4759f],
  [0.8782f, 0.3402f, 0.3725f],
  [0.9755f, 0.5470f, 0.3027f],
  [0.9871f, 0.9914f, 0.7491f],   # near-white-yellow
]

proc magmaSample(t: float32): array[3, byte] {.inline.} =
  ## Sample the magma ramp at parameter t in [0, 1]. Out-of-range
  ## values are clamped.
  var u = t
  if u < 0.0f: u = 0.0f
  elif u > 1.0f: u = 1.0f
  let f = u * float32(magmaStops.high)
  let i = int(f)
  let frac = f - float32(i)
  let i2 = if i >= magmaStops.high: magmaStops.high else: i + 1
  let a = magmaStops[i]
  let b = magmaStops[i2]
  let r = a[0] + frac * (b[0] - a[0])
  let g = a[1] + frac * (b[1] - a[1])
  let bl = a[2] + frac * (b[2] - a[2])
  result[0] = byte(min(255, max(0, int(r * 255.0f + 0.5f))))
  result[1] = byte(min(255, max(0, int(g * 255.0f + 0.5f))))
  result[2] = byte(min(255, max(0, int(bl * 255.0f + 0.5f))))

# ---------------------------------------------------------------------------
# Public entry point.
# ---------------------------------------------------------------------------

type
  PngWriteError* = object of CatchableError

proc writeMagmaPng*(errorMap: openArray[float32];
                    width, height: int;
                    dst: string) {.raises: [PngWriteError].} =
  ## Render `errorMap` (length width*height, values in [0, 1]) as a
  ## magma-mapped 8-bit-per-channel RGB PNG at `dst`. Raises
  ## `PngWriteError` on failure.
  if width <= 0 or height <= 0:
    raise (ref PngWriteError)(msg: "writeMagmaPng: invalid dimensions " &
                                   $width & "x" & $height)
  if errorMap.len != width * height:
    raise (ref PngWriteError)(msg: "writeMagmaPng: errorMap.len " &
                                   $errorMap.len & " != width*height = " &
                                   $(width * height))
  var rgb = newSeq[byte](width * height * 3)
  for i in 0 ..< errorMap.len:
    let c = magmaSample(errorMap[i])
    rgb[i * 3 + 0] = c[0]
    rgb[i * 3 + 1] = c[1]
    rgb[i * 3 + 2] = c[2]
  let stride = cint(width * 3)
  let rc = stbi_write_png(cstring(dst), cint(width), cint(height),
                          cint(3), addr rgb[0], stride)
  if rc == 0:
    raise (ref PngWriteError)(msg: "stbi_write_png failed for " & dst)

{.pop.}
