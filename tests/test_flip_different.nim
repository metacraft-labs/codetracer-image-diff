## tests/test_flip_different.nim
##
## Visibly-different inputs → large FLIP error. We take a deterministic
## gradient and produce a "candidate" with the red channel inverted
## (R' = 255 - R). For natural images this is a dramatic perceptual
## change everywhere; we expect mean error well above 0.5.

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
      result[i + 0] = byte(x)
      result[i + 1] = byte(y)
      result[i + 2] = byte((x + y) and 0xff)
      result[i + 3] = 255

let reference = makeGradient()
var candidate = reference
for y in 0 ..< H:
  for x in 0 ..< W:
    let i = (y * W + x) * C
    candidate[i + 0] = 255 - candidate[i + 0]   # invert R
    # Also invert G to make sure we're not getting a fortunate
    # luminance-cancellation case at low x,y. FLIP measures perceptual
    # difference in YCxCz space, so a single-channel inversion at the
    # origin (where R=0) is a no-op for that pixel.
    candidate[i + 1] = 255 - candidate[i + 1]

let res = flip(reference, candidate, W, H, C)

echo &"different: mean={res.mean:.4f} maxError={res.maxError:.4f} " &
     &"p50={res.p50:.4f} p90={res.p90:.4f} p99={res.p99:.4f}"

doAssert res.mean > 0.5'f32,
  &"two-channel-inverted inputs should have mean > 0.5, got {res.mean}"

echo "test_flip_different: PASSED"
