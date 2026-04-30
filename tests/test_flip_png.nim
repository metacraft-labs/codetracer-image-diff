## tests/test_flip_png.nim
##
## End-to-end check on `renderFlipPng`: take a non-trivial FLIP result
## (the subpixel-shift fixture from test_flip_subpixel.nim — which has
## visible error along the edge), render to PNG, then verify:
##
##   1. The output file exists.
##   2. It has more than 500 bytes (a degenerate PNG is ~67 bytes;
##      our magma-mapped 256x256 image should be in the kilobytes
##      range).
##   3. The first 8 bytes are the PNG magic signature
##      (89 50 4E 47 0D 0A 1A 0A).

import std/[os, strformat, strutils]
import ../src/image_diff

const
  W = 256
  H = 256
  C = 4

proc makeSplitImage(shift: int): seq[byte] =
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
let candidate = makeSplitImage(1)
let res = flip(reference, candidate, W, H, C)

let outDir = currentSourcePath().parentDir() / "output"
createDir(outDir)
let outPath = outDir / "flip_subpixel_error.png"

if fileExists(outPath):
  removeFile(outPath)

renderFlipPng(res, outPath)

doAssert fileExists(outPath), "PNG was not written: " & outPath

let info = getFileInfo(outPath)
echo &"png: {outPath} ({info.size} bytes)"

doAssert info.size > 500,
  &"PNG should be > 500 bytes, got {info.size} bytes"

# Check the PNG magic signature: 89 50 4E 47 0D 0A 1A 0A
const pngMagic = [
  byte(0x89), byte(0x50), byte(0x4e), byte(0x47),
  byte(0x0d), byte(0x0a), byte(0x1a), byte(0x0a),
]

block:
  let f = open(outPath, fmRead)
  defer: f.close()
  var buf: array[8, byte]
  let nRead = f.readBytes(buf, 0, 8)
  doAssert nRead == 8, &"could not read 8 bytes from {outPath}, got {nRead}"
  for i in 0 ..< 8:
    doAssert buf[i] == pngMagic[i],
      &"PNG magic mismatch at byte {i}: got 0x{buf[i].int.toHex(2)}, " &
      &"expected 0x{pngMagic[i].int.toHex(2)}"

echo "test_flip_png: PASSED"
