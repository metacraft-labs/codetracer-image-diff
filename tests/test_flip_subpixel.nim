## tests/test_flip_subpixel.nim
##
## **Primary acceptance signal for the library.**
##
## A naive per-pixel diff between an image and a 1-pixel-shifted copy
## fires loudly along every edge. FLIP, being neighborhood-aware,
## should report a much smaller mean error — the whole point of this
## metric is to tolerate the rasterizer-rounding noise that produces
## exactly this kind of single-pixel shift between Mesa and NVIDIA.
##
## Test image: a hard 64x128 black/white split centred in a 256x256
## canvas. The "candidate" is the same image shifted right by 1 pixel.
## A per-pixel diff would report ~50% of the boundary pixels as fully
## different (mean ~0.25 over the whole image, since the boundary is a
## thin strip but the absolute-difference spike is enormous). FLIP
## should give us mean < 0.1.

import std/[strformat]
import ../src/image_diff

const
  W = 256
  H = 256
  C = 4

proc makeSplitImage(shift: int): seq[byte] =
  ## A 64-wide black region centred horizontally, with 128 px of vertical
  ## extent centred vertically; the rest is mid-grey. The black/grey
  ## transition is offset rightward by `shift` pixels.
  result = newSeq[byte](W * H * C)
  let blackLeft = (W - 64) div 2 + shift
  let blackRight = blackLeft + 64
  let blackTop = (H - 128) div 2
  let blackBottom = blackTop + 128
  for y in 0 ..< H:
    for x in 0 ..< W:
      let i = (y * W + x) * C
      let inBlack = (x >= blackLeft and x < blackRight and
                     y >= blackTop and y < blackBottom)
      let v = if inBlack: byte(0) else: byte(192)
      result[i + 0] = v
      result[i + 1] = v
      result[i + 2] = v
      result[i + 3] = 255

let reference = makeSplitImage(0)
let candidate = makeSplitImage(1)   # 1-pixel rightward shift

let res = flip(reference, candidate, W, H, C)

echo &"subpixel: mean={res.mean:.4f} maxError={res.maxError:.4f} " &
     &"p50={res.p50:.4f} p90={res.p90:.4f} p99={res.p99:.4f}"

doAssert res.mean < 0.1'f32,
  &"FLIP should tolerate a 1-pixel edge shift; got mean={res.mean}. " &
  "If this fails the FLIP integration is wrong (e.g. a per-pixel diff " &
  "was wired up by mistake)."

echo "test_flip_subpixel: PASSED"
