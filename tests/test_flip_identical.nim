## tests/test_flip_identical.nim
##
## Identical inputs → near-zero FLIP error. The 256x256 buffer is filled
## with a deterministic gradient so we exercise a non-trivial colour
## distribution (FLIP on a uniformly-grey image is degenerate). Both
## sides hold byte-identical bytes; we expect mean and max error
## essentially at the floating-point noise floor.

import std/[strformat]
import ../src/image_diff

const
  W = 256
  H = 256
  C = 4

proc makeGradient(): seq[byte] =
  result = newSeq[byte](W * H * C)
  for y in 0 ..< H:
    for x in 0 ..< W:
      let i = (y * W + x) * C
      result[i + 0] = byte(x)            # R: horizontal ramp
      result[i + 1] = byte(y)            # G: vertical ramp
      result[i + 2] = byte((x + y) and 0xff)  # B: diagonal ramp
      result[i + 3] = 255                # A: opaque

let buf = makeGradient()
let res = flip(buf, buf, W, H, C)

doAssert res.width == W
doAssert res.height == H
doAssert res.errorMap.len == W * H

echo &"identical: mean={res.mean:.6f} maxError={res.maxError:.6f} " &
     &"p50={res.p50:.6f} p90={res.p90:.6f} p99={res.p99:.6f}"

doAssert res.mean < 0.001'f32,
  &"identical inputs should have near-zero mean error, got {res.mean}"
doAssert res.maxError < 0.01'f32,
  &"identical inputs should have near-zero max error, got {res.maxError}"

echo "test_flip_identical: PASSED"
